import 'dart:async';
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
    this.isSending = false,
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

// Protocol message types sent over the WebSocket
// SENDER → RECEIVER: {"type":"meta","index":0,"name":"file.jpg","size":12345}
// SENDER → RECEIVER: binary bytes (raw file chunks)
// SENDER → RECEIVER: {"type":"done","index":0}
// RECEIVER → SENDER: {"type":"ready"}   (receiver is connected and waiting)
// RECEIVER → SENDER: {"type":"next"}    (ready for next file)

class TransferNotifier extends StateNotifier<TransferState> {
  TransferNotifier() : super(TransferState(files: []));

  final _p2p = FlutterP2pConnection();
  static const String _goIp = '192.168.49.1';

  // Used on receiver side to accumulate incoming file bytes
  IOSink? _currentSink;
  int _expectedBytes = 0;
  int _receivedBytes = 0;
  int _currentFileIndex = 0;
  List<FileItem> _receiverFiles = [];
  String _savePath = '';
  DateTime _lastSpeedUpdate = DateTime.now();
  int _lastSpeedBytes = 0;

  void reset() {
    _p2p.closeSocket();
    _currentSink?.close();
    _currentSink = null;
    state = TransferState(files: []);
  }

  @override
  void dispose() {
    _p2p.closeSocket();
    _currentSink?.close();
    super.dispose();
  }

  // ─── SENDER ────────────────────────────────────────────────────────────────

  Future<void> startSending(
    List<FileItem> files,
    String groupOwnerAddress,
    bool isGroupOwner,
  ) async {
    state = TransferState(files: files, isSending: true);

    final readyCompleter = Completer<void>();

    void onConnect(String address) {
      // Socket connected — wait for receiver's "ready" signal before sending
    }

    void onRequest(dynamic data) {
      if (data is String) {
        try {
          final msg = jsonDecode(data);
          if (msg['type'] == 'ready' && !readyCompleter.isCompleted) {
            readyCompleter.complete();
          }
          if (msg['type'] == 'progress' && mounted) {
            state = state.copyWith(
              overallProgress: (msg['overall'] as num?)?.toDouble() ?? 0.0,
              currentFileIndex: msg['current'] ?? 0,
              speedMBs: (msg['speed'] as num?)?.toDouble() ?? 0.0,
            );
          }
        } catch (_) {}
      }
    }

    bool connected = false;
    if (isGroupOwner) {
      // Sender is GO: bind socket server, receiver will connect to us
      connected = await _p2p.startSocket(
        groupOwnerAddress: _goIp,
        onConnect: onConnect,
        onRequest: onRequest,
      );
    } else {
      // Sender is client: connect to GO's socket
      for (int attempt = 0; attempt < 8 && !connected; attempt++) {
        connected = await _p2p.connectToSocket(
          groupOwnerAddress: _goIp,
          onConnect: onConnect,
          onRequest: onRequest,
        );
        if (!connected) await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!connected) {
      if (mounted)
        state = state.copyWith(error: 'Could not establish socket connection.');
      return;
    }

    // Wait for receiver to signal ready (max 30s)
    try {
      await readyCompleter.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      if (mounted)
        state = state.copyWith(error: 'Receiver did not respond in time.');
      return;
    }

    // Send files one by one over the socket
    await _sendFilesOverSocket(files);
  }

  Future<void> _sendFilesOverSocket(List<FileItem> files) async {
    const int chunkSize = 64 * 1024; // 64 KB chunks

    for (int i = 0; i < files.length; i++) {
      if (!mounted) break;
      final fileItem = files[i];
      final file = File(fileItem.path);

      if (!await file.exists()) {
        if (mounted) {
          state = state.copyWith(
            error: 'File not found: ${fileItem.name}\nPath: "${fileItem.path}"',
          );
        }
        return;
      }

      final fileSize = await file.length();

      // Send metadata header
      _p2p.sendStringToSocket(
        jsonEncode({
          'type': 'meta',
          'index': i,
          'name': fileItem.name,
          'size': fileSize,
          'total': files.length,
        }),
      );

      // Small delay to ensure metadata arrives before binary data
      await Future.delayed(const Duration(milliseconds: 100));

      // Stream file bytes in chunks
      int sent = 0;
      DateTime lastUpdate = DateTime.now();
      int lastBytes = 0;

      await for (final chunk in file.openRead()) {
        if (!mounted) break;
        // Send in fixed-size chunks to avoid overwhelming the socket
        for (int offset = 0; offset < chunk.length; offset += chunkSize) {
          final end = (offset + chunkSize).clamp(0, chunk.length);
          final slice = chunk.sublist(offset, end);
          _p2p.sendStringToSocket(base64Encode(slice));
          sent += slice.length;

          final now = DateTime.now();
          if (now.difference(lastUpdate).inMilliseconds > 300) {
            final secs = now.difference(lastUpdate).inMilliseconds / 1000.0;
            final speed = (sent - lastBytes) / (1024 * 1024 * secs);
            final fileProg = fileSize > 0 ? sent / fileSize : 0.0;
            if (mounted) {
              state = state.copyWith(
                currentFileIndex: i,
                currentFileProgress: fileProg,
                overallProgress: (i + fileProg) / files.length,
                speedMBs: speed,
              );
            }
            lastUpdate = now;
            lastBytes = sent;
          }
        }
      }

      // Signal end of this file
      _p2p.sendStringToSocket(jsonEncode({'type': 'done', 'index': i}));

      if (mounted) {
        state = state.copyWith(
          currentFileIndex: i,
          currentFileProgress: 1.0,
          overallProgress: (i + 1) / files.length,
        );
      }

      // Wait a bit between files
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted)
      state = state.copyWith(isCompleted: true, overallProgress: 1.0);
  }

  // ─── RECEIVER ──────────────────────────────────────────────────────────────

  Future<void> startReceiving(
    String groupOwnerAddress,
    bool isGroupOwner,
  ) async {
    state = TransferState(files: [], isSending: false);

    final Directory? dir = await getExternalStorageDirectory();
    _savePath = '${dir?.path}/DataTransfer';
    await Directory(_savePath).create(recursive: true);

    _currentFileIndex = 0;
    _receiverFiles = [];
    _currentSink = null;
    _expectedBytes = 0;
    _receivedBytes = 0;

    void onConnect(String address) {
      // Signal sender that we're ready to receive
      _p2p.sendStringToSocket(jsonEncode({'type': 'ready'}));
    }

    void onRequest(dynamic data) {
      _handleReceiverData(data);
    }

    bool connected = false;
    if (isGroupOwner) {
      // Receiver is GO: bind socket server
      connected = await _p2p.startSocket(
        groupOwnerAddress: _goIp,
        onConnect: onConnect,
        onRequest: onRequest,
      );
    } else {
      // Receiver is client: connect to GO's socket
      for (int attempt = 0; attempt < 8 && !connected; attempt++) {
        connected = await _p2p.connectToSocket(
          groupOwnerAddress: _goIp,
          onConnect: onConnect,
          onRequest: onRequest,
        );
        if (!connected) await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!connected && mounted) {
      state = state.copyWith(error: 'Could not connect to sender socket.');
    }
  }

  void _handleReceiverData(dynamic data) {
    if (data is String) {
      // Try to parse as JSON control message first
      try {
        final msg = jsonDecode(data);
        final type = msg['type'] as String?;

        if (type == 'meta') {
          // New file incoming
          _currentFileIndex = msg['index'] as int;
          final name = msg['name'] as String;
          final size = msg['size'] as int;
          final total = msg['total'] as int;

          _expectedBytes = size;
          _receivedBytes = 0;
          _lastSpeedUpdate = DateTime.now();
          _lastSpeedBytes = 0;

          final fileItem = FileItem(
            id: name,
            name: name,
            sizeMB: size / (1024 * 1024),
            type: _inferType(name),
            path: '$_savePath/$name',
          );

          // Add to file list if not already there
          final existing = List<FileItem>.from(state.files);
          if (_currentFileIndex >= existing.length) {
            existing.add(fileItem);
          } else {
            existing[_currentFileIndex] = fileItem;
          }
          _receiverFiles = existing;

          if (mounted) {
            state = state.copyWith(
              files: existing,
              currentFileIndex: _currentFileIndex,
              currentFileProgress: 0.0,
              overallProgress: _currentFileIndex / total,
            );
          }

          // Open file for writing
          _currentSink?.close();
          _currentSink = File('$_savePath/$name').openWrite();
        } else if (type == 'done') {
          // File transfer complete
          _currentSink?.close();
          _currentSink = null;
          final total = _receiverFiles.length;
          final idx = msg['index'] as int;

          if (mounted) {
            state = state.copyWith(
              currentFileIndex: idx,
              currentFileProgress: 1.0,
              overallProgress: (idx + 1) / total,
              isCompleted: idx == total - 1,
            );
          }
        }
        return;
      } catch (_) {
        // Not JSON — it's a base64-encoded file chunk
      }

      // Decode base64 chunk and write to file
      try {
        final bytes = base64Decode(data);
        _currentSink?.add(bytes);
        _receivedBytes += bytes.length;

        final now = DateTime.now();
        if (now.difference(_lastSpeedUpdate).inMilliseconds > 300) {
          final secs = now.difference(_lastSpeedUpdate).inMilliseconds / 1000.0;
          final speed =
              (_receivedBytes - _lastSpeedBytes) / (1024 * 1024 * secs);
          final fileProg = _expectedBytes > 0
              ? _receivedBytes / _expectedBytes
              : 0.0;
          final total = _receiverFiles.length;

          if (mounted) {
            state = state.copyWith(
              currentFileProgress: fileProg,
              overallProgress: total > 0
                  ? (_currentFileIndex + fileProg) / total
                  : 0.0,
              speedMBs: speed,
            );
            // Report progress back to sender
            _p2p.sendStringToSocket(
              jsonEncode({
                'type': 'progress',
                'overall': total > 0
                    ? (_currentFileIndex + fileProg) / total
                    : 0.0,
                'current': _currentFileIndex,
                'speed': speed,
              }),
            );
          }
          _lastSpeedUpdate = now;
          _lastSpeedBytes = _receivedBytes;
        }
      } catch (_) {}
    }
  }

  String _inferType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext))
      return 'Photo';
    if (['mp4', 'mkv', 'avi', 'mov', 'webm'].contains(ext)) return 'Video';
    if (['mp3', 'aac', 'wav', 'flac', 'ogg'].contains(ext)) return 'Audio';
    return 'File';
  }
}

final transferProvider = StateNotifierProvider<TransferNotifier, TransferState>(
  (ref) => TransferNotifier(),
);
