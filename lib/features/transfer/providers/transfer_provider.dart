import 'dart:convert';
import 'dart:io';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  TransferState({
    required this.files,
    this.overallProgress = 0.0,
    this.currentFileProgress = 0.0,
    this.currentFileIndex = 0,
    this.speedMBs = 0.0,
    this.isCompleted = false,
    this.isSending = true,
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

class TransferNotifier extends Notifier<TransferState> {
  final _p2pConnection = FlutterP2pConnection();
  HttpServer? _server;

  @override
  TransferState build() {
    ref.onDispose(() {
      _server?.close();
      _p2pConnection.closeSocket();
    });
    return TransferState(files: []);
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
              request.response.headers.contentType = ContentType.binary;
              request.response.headers.contentLength = await file.length();
              await request.response.addStream(file.openRead());
            } else {
              request.response.statusCode = HttpStatus.notFound;
            }
          } catch (e) {
            request.response.statusCode = HttpStatus.notFound;
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

  Future<void> startSending(List<FileItem> files, String groupOwnerAddress, bool isGroupOwner) async {
    state = TransferState(files: files, isSending: true);
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
        onRequest: (data) => print('Sender (GO): Received: $data'),
      );
    } else {
      print('Sender: Connecting to P2P Socket as Client at $normalizedAddress...');
      await _p2pConnection.connectToSocket(
        groupOwnerAddress: normalizedAddress,
        onConnect: (address) {
          print('Sender (Client): Connected to host: $address');
          Future.delayed(const Duration(seconds: 1), () => _sendMetadata(files));
        },
        onRequest: (data) => print('Sender (Client): Received: $data'),
      );
    }
  }

  void _sendMetadata(List<FileItem> files) {
    print('Sender: Preparing metadata for ${files.length} files...');
    final metadata = {
      'type': 'metadata',
      'files': files.map((f) => {
        'name': f.name,
        'sizeMB': f.sizeMB,
        'type': f.type,
      }).toList(),
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
      connected = true;
      _p2pConnection.sendStringToSocket(jsonEncode({'type': 'ping', 'message': 'Hello from Receiver'}));
    };

    final onRequest = (data) async {
      print('Receiver: Socket received data: $data');
      try {
        final decoded = jsonDecode(data.toString());
        if (decoded['type'] == 'metadata') {
          print('Receiver: Valid metadata JSON detected.');
          final List<dynamic> incomingFiles = decoded['files'];
          final files = incomingFiles.map((f) => FileItem(
            id: f['name'],
            name: f['name'],
            sizeMB: f['sizeMB'],
            type: f['type'],
            path: '', 
          )).toList();
          
          state = state.copyWith(files: files);
          await _downloadFiles(hostAddress, files);
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

  Future<void> _downloadFiles(String hostAddress, List<FileItem> files) async {
    final Directory? downloadDir = await getExternalStorageDirectory();
    final String savePath = '${downloadDir?.path}/DataTransfer';
    final dir = Directory(savePath);
    if (!await dir.exists()) await dir.create(recursive: true);

    for (int i = 0; i < files.length; i++) {
        final file = files[i];
        state = state.copyWith(currentFileIndex: i, currentFileProgress: 0.0);
        
        try {
          final client = HttpClient();
          final request = await client.getUrl(Uri.parse('http://$hostAddress:9000/download?name=${Uri.encodeComponent(file.name)}'));
          final response = await request.close();
          
          if (response.statusCode == 200) {
             final fileToSave = File('$savePath/${file.name}');
             final sink = fileToSave.openWrite();
             
             int downloaded = 0;
             final total = response.contentLength;
             
             await response.listen((chunk) {
               sink.add(chunk);
               downloaded += chunk.length;
               if (total > 0) {
                 state = state.copyWith(
                   currentFileProgress: downloaded / total,
                   overallProgress: (i + (downloaded / total)) / files.length,
                 );
               }
             }).asFuture();
             
             await sink.close();
             print('Downloaded ${file.name}');
          }
        } catch (e) {
          print('Error downloading ${file.name}: $e');
        }
    }
    
    state = state.copyWith(isCompleted: true, overallProgress: 1.0);
  }
}

final transferProvider = NotifierProvider<TransferNotifier, TransferState>(() => TransferNotifier());
