import 'dart:convert';
import 'dart:io';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/models/file_item.dart';

class TransferState {
  final List<FileItem> files;
  final double overallProgress;
  final double currentFileProgress;
  final int currentFileIndex;
  final double speedMBs;
  final bool isCompleted;
  final bool isSending;
  final String? error;
  
  bool get isTransferring => !isCompleted && files.isNotEmpty && error == null;

  TransferState({
    required this.files,
    this.overallProgress = 0.0,
    this.currentFileProgress = 0.0,
    this.currentFileIndex = 0,
    this.speedMBs = 0.0,
    this.isCompleted = false,
    this.isSending = false, // Default to false
    this.error,
  });

  TransferState copyWith({
    List<FileItem>? files,
    double? overallProgress,
    double? currentFileProgress,
    int? currentFileIndex,
    double? speedMBs,
    bool? isCompleted,
    bool? isSending,
    String? error,
  }) {
    return TransferState(
      files: files ?? this.files,
      overallProgress: overallProgress ?? this.overallProgress,
      currentFileProgress: currentFileProgress ?? this.currentFileProgress,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      speedMBs: speedMBs ?? this.speedMBs,
      isCompleted: isCompleted ?? this.isCompleted,
      isSending: isSending ?? this.isSending,
      error: error ?? this.error,
    );
  }
}

class TransferNotifier extends StateNotifier<TransferState> {
  TransferNotifier() : super(TransferState(files: []));

  void reset() {
    print('TransferNotifier: reset called. Clearing state.');
    state = TransferState(files: [], isSending: false, overallProgress: 0.0);
    _server?.close();
    _server = null;
    _protocolTriggered = false;
    _lastConnectedAddress = null;
    print('TransferNotifier: State Reset');
  }

  final _p2pConnection = FlutterP2pConnection();
  HttpServer? _server;
  String? _lastConnectedAddress;
  bool _protocolTriggered = false;

  @override
  void dispose() {
    print('Disposing TransferNotifier...');
    _server?.close();
    _p2pConnection.closeSocket();
    super.dispose();
  }

  Future<void> _startFileServer(List<FileItem> files) async {
    try {
      // Close existing server if any
      await _server?.close(force: true);

      _server = await HttpServer.bind(InternetAddress.anyIPv4, 9000);
      print('File Server listening on port 9000');

      _server!.listen((HttpRequest request) async {
        if (request.uri.path == '/download') {
          final fileName = request.uri.queryParameters['name'];
          try {
            final fileItem = files.firstWhere((f) => f.name == fileName);
            final file = File(fileItem.path);

            if (await file.exists()) {
              try {
                print('TransferNotifier: Sending file stream: ${file.path}');
                request.response.headers.contentType = ContentType.binary;
                request.response.headers.contentLength = await file.length();
                await request.response.addStream(file.openRead());
              } catch (e) {
                print('TransferNotifier: Stream error during send: $e');
              } finally {
                try {
                  await request.response.close();
                } catch (_) {}
              }
            } else {
              request.response.statusCode = HttpStatus.notFound;
              await request.response.close();
            }
          } catch (e) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });
    } catch (e) {
      print('Error starting file server: $e');
    }
  }

  Future<void> startSending(
    List<FileItem> files,
    String groupOwnerAddress,
    bool isGroupOwner,
  ) async {
    _protocolTriggered = true;
    print('TransferNotifier: startSending called. Setting isSending = true. Files: ${files.length}');
    state = TransferState(files: files, isSending: true, overallProgress: 0.0);
    print('Starting Sender Protocol... isGroupOwner: $isGroupOwner');

    await _startFileServer(files);

    final normalizedAddress = groupOwnerAddress.replaceFirst("/", "");

    if (isGroupOwner) {
      print('Sender: Binding P2P Socket as Server at $normalizedAddress...');
      await _p2pConnection.startSocket(
        groupOwnerAddress: normalizedAddress,
        onConnect: (address) {
          print('Sender (GO): Client connected: $address');
          Future.delayed(const Duration(seconds: 1), () => _sendMetadata(files));
        },
        onRequest: (data) {
          print('Sender (GO): Received: $data');
          _handleSocketMessage(data);
        },
      );
    } else {
      print('Sender: Connecting to P2P Socket as Client at $normalizedAddress...');
      bool connected = false;
      int retries = 0;
      while (!connected && retries < 5) {
        await _p2pConnection.connectToSocket(
          groupOwnerAddress: normalizedAddress,
          onConnect: (address) {
            print('Sender (Client): Connected to host: $address');
            connected = true;
            Future.delayed(const Duration(seconds: 1), () => _sendMetadata(files));
          },
          onRequest: (data) {
            print('Sender (Client): Received: $data');
            _handleSocketMessage(data);
          },
        );
        if (connected) break;
        retries++;
        print('Sender: Connection attempt $retries failed, retrying...');
        await Future.delayed(const Duration(seconds: 2));
      }

      if (!connected) {
        state = state.copyWith(
          error: 'Sender: Failed to connect to Receiver socket.',
        );
      }
    }
  }

  void _sendMetadata(List<FileItem> files) {
    print('Sender: Preparing metadata for ${files.length} files...');
    final metadata = {
      'type': 'metadata',
      'files': files
          .map((f) => {'name': f.name, 'sizeMB': f.sizeMB, 'type': f.type})
          .toList(),
    };
    final jsonString = jsonEncode(metadata);
    print('Sender: Sending metadata (size: ${jsonString.length} chars)');
    _p2pConnection.sendStringToSocket(jsonString);
  }

  Future<void> startReceiving(String hostAddress, bool isGroupOwner) async {
    state = TransferState(files: [], isSending: false);
    print('Starting Receiver Protocol... isGroupOwner: $isGroupOwner');

    bool connected = false;

    final onConnect = (address) {
      print('Receiver Socket Connected: $address');
      _lastConnectedAddress = address; // Store the sender's IP if we are GO
      connected = true;
      _p2pConnection.sendStringToSocket(
        jsonEncode({'type': 'ping', 'message': 'Hello from Receiver'}),
      );
    };

    final onRequest = (data) async {
      print('Receiver: Socket received data: $data');
      try {
        final decoded = jsonDecode(data.toString());
        if (decoded['type'] == 'metadata') {
          print('Receiver: Valid metadata JSON detected.');
          final List<dynamic> incomingFiles = decoded['files'];
          final files = incomingFiles
              .map(
                (f) => FileItem(
                  id: f['name'],
                  name: f['name'],
                  sizeMB: f['sizeMB'],
                  type: f['type'],
                  path: '',
                ),
              )
              .toList();

          if (!mounted) return;
          state = state.copyWith(files: files);

          // If we are GO, we download from the client's IP (_lastConnectedAddress)
          // If we are Client, we download from the GO's IP (hostAddress)
          // IMPORTANT: Capture only the IP, strip the port if present (e.g. 192.168.49.123:4045)
          String downloadHost = hostAddress
              .replaceFirst("/", "")
              .split(':')
              .first;

    // DYNAMIC IP RESOLUTION
    String realTargetAddress = hostAddress;
    if (isGroupOwner) {
      // If we ARE the GO, we connect to the first client
      // Assuming info is available or passed contextually
      // realTargetAddress = info.clients[0].deviceAddress; 
    } else {
      // If we are CLient, target is ALWAYS the GO address
      realTargetAddress = hostAddress.replaceFirst('/', '');
    }
    
    print('TransferNotifier: Real Target IP resolved to: $realTargetAddress');
    _lastConnectedAddress = realTargetAddress;

          if (isGroupOwner && _lastConnectedAddress != null) {
            downloadHost = _lastConnectedAddress!
                .replaceFirst("/", "")
                .split(':')
                .first;
            print('Receiver (Host): Using Sender (Client) IP: $downloadHost');
          } else {
            print('Receiver (Client): Using Host IP: $downloadHost');
          }

          print('Receiver: Initiating download from $downloadHost:9000');
          await _downloadFiles(downloadHost, files);
        }
      } catch (e) {
        print('Receiver: Error handling metadata: $e');
      }
    };

    if (isGroupOwner) {
      print('Receiver: Binding P2P Socket as Server at $hostAddress...');
      await _p2pConnection.startSocket(
        groupOwnerAddress: hostAddress.replaceFirst("/", ""),
        onConnect: onConnect,
        onRequest: onRequest,
      );
    } else {
      print('Receiver: Connecting to P2P Socket as Client at $hostAddress...');
      // Retried connection logic moved inside for robustness
      int retries = 0;
      while (!connected && retries < 5) {
        await _p2pConnection.connectToSocket(
          groupOwnerAddress: hostAddress.replaceFirst("/", ""),
          onConnect: onConnect,
          onRequest: onRequest,
        );
        if (connected) break;
        retries++;
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    // Give it a moment to confirm connection state if it's a server (it doesn't "connect" itself)
    if (isGroupOwner) connected = true;

    if (!connected) {
      state = state.copyWith(error: 'Failed to establish socket connection.');
    }
  }

  Future<void> _downloadFiles(String downloadHost, List<FileItem> files) async {
    final Directory? downloadDir = await getExternalStorageDirectory();
    final String savePath = '${downloadDir?.path}/DataTransfer';
    final dir = Directory(savePath);
    if (!await dir.exists()) await dir.create(recursive: true);

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      if (mounted) state = state.copyWith(currentFileIndex: i, currentFileProgress: 0.0);

      try {
        final client = HttpClient();
        final url =
            'http://$downloadHost:9000/download?name=${Uri.encodeComponent(file.name)}';
        print('Receiver: GET $url');

        final request = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 5));
        final response = await request.close();

        print('Receiver: Response status: ${response.statusCode} from $downloadHost');

        if (response.statusCode == 200) {
          final fileToSave = File('$savePath/${file.name}');
          print('Receiver: Saving to ${fileToSave.path}');
          final sink = fileToSave.openWrite();

          int downloaded = 0;
          final total = response.contentLength;
          print('Receiver: File size: $total bytes');

          DateTime lastUpdateTime = DateTime.now();
          int lastDownloaded = 0;

          await response.listen((chunk) {
            sink.add(chunk);
            downloaded += chunk.length;
            
            final now = DateTime.now();
            if (now.difference(lastUpdateTime).inMilliseconds > 500) {
              final double duration = now.difference(lastUpdateTime).inMilliseconds / 1000.0;
              final double speed = (downloaded - lastDownloaded) / (1024 * 1024 * duration);
              
              if (!mounted) return;
              state = state.copyWith(
                currentFileProgress: downloaded / total,
                overallProgress: (i + (downloaded / total)) / files.length,
                speedMBs: speed,
              );
              
              // Sync progress back to Sender
              _p2pConnection.sendStringToSocket(jsonEncode({
                'type': 'progress',
                'overall': (i + (downloaded / total)) / files.length,
                'current': i,
                'speed': speed,
              }));
              
              lastUpdateTime = now;
              lastDownloaded = downloaded;
            }
          }).asFuture();

          await sink.close();
          print('Receiver: Successfully saved ${file.name}');
        } else {
          print('Receiver: Download failed with status ${response.statusCode}');
        }
      } catch (e) {
        print('Receiver: Exception during download of ${file.name}: $e');
      }
    }

    state = state.copyWith(isCompleted: true, overallProgress: 1.0);
  }

  void _handleSocketMessage(dynamic data) {
    try {
      final decoded = jsonDecode(data.toString());
      if (decoded['type'] == 'progress') {
        if (!mounted) return;
        state = state.copyWith(
          overallProgress: decoded['overall']?.toDouble() ?? 0.0,
          currentFileIndex: decoded['current'] ?? 0,
          speedMBs: decoded['speed']?.toDouble() ?? 0.0,
        );
      }
    } catch (e) {
      print('Error handling socket message: $e');
    }
  }
}

final transferProvider = StateNotifierProvider<TransferNotifier, TransferState>(
  (ref) {
    return TransferNotifier();
  },
);
