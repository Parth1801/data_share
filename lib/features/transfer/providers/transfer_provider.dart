import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:flutter_riverpod/legacy.dart';
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

// Wire protocol (all messages are strings over the WebSocket):
//   SENDER → RECEIVER: JSON {"type":"meta","index":0,"name":"x.jpg","size":1234,"total":3}
//   SENDER → RECEIVER: base64-encoded file chunk strings
//   SENDER → RECEIVER: JSON {"type":"done","index":0}
//   RECEIVER → SENDER: JSON {"type":"ready"}
//   RECEIVER → SENDER: JSON {"type":"progress","overall":0.5,"current":0,"speed":1.2}

class TransferNotifier extends StateNotifier<TransferState> {
  TransferNotifier() : super(TransferState(files: []));

  final _p2p = FlutterP2pConnection();
  static const String _goIp = '192.168.49.1';
  // Public folder — visible to gallery and file manager apps
  static const String _saveDir = '/storage/emulated/0/Pictures/DataTransfer';

  // Receiver-side state
  IOSink? _sink;
  int _expectedBytes = 0;
  int _receivedBytes = 0;
  int _rxFileIndex = 0;
  List<FileItem> _rxFiles = [];
  DateTime _lastSpeedTime = DateTime.now();
  int _lastSpeedBytes = 0;

  void reset() {
    _p2p.closeSocket();
    _sink?.close();
    _sink = null;
    state = TransferState(files: []);
  }

  @override
  void dispose() {
    _p2p.closeSocket();
    _sink?.close();
    super.dispose();
  }

  // ── SENDER ─────────────────────────────────────────────────────────────────

  Future<void> startSending(
    List<FileItem> files,
    String groupOwnerAddress,
    bool isGroupOwner,
  ) async {
    state = TransferState(files: files, isSending: true);

    final readyCompleter = Completer<void>();

    bool connected = false;
    if (isGroupOwner) {
      connected = await _p2p.startSocket(
        groupOwnerAddress: _goIp,
        onConnect: (_) {},
        onRequest: (data) => _onSenderMessage(data, readyCompleter),
      );
    } else {
      for (int i = 0; i < 8 && !connected; i++) {
        connected = await _p2p.connectToSocket(
          groupOwnerAddress: _goIp,
          onConnect: (_) {},
          onRequest: (data) => _onSenderMessage(data, readyCompleter),
        );
        if (!connected) await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!connected) {
      if (mounted)
        state = state.copyWith(error: 'Could not establish socket connection.');
      return;
    }

    try {
      await readyCompleter.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      if (mounted)
        state = state.copyWith(error: 'Receiver did not respond in time.');
      return;
    }

    await _sendFiles(files);
  }

  void _onSenderMessage(dynamic data, Completer<void> readyCompleter) {
    if (data is! String) return;
    try {
      final msg = jsonDecode(data);
      if (msg['type'] == 'ready' && !readyCompleter.isCompleted) {
        readyCompleter.complete();
      } else if (msg['type'] == 'progress' && mounted) {
        state = state.copyWith(
          overallProgress: (msg['overall'] as num?)?.toDouble() ?? 0.0,
          currentFileIndex: msg['current'] ?? 0,
          speedMBs: (msg['speed'] as num?)?.toDouble() ?? 0.0,
        );
      }
    } catch (_) {}
  }

  Future<void> _sendFiles(List<FileItem> files) async {
    const chunkSize = 64 * 1024; // 64 KB

    for (int i = 0; i < files.length; i++) {
      if (!mounted) break;
      final item = files[i];
      final file = File(item.path);

      if (item.path.isEmpty || !await file.exists()) {
        if (mounted) {
          state = state.copyWith(
            error: 'File not found: ${item.name}\nPath: "${item.path}"',
          );
        }
        return;
      }

      final fileSize = await file.length();

      _p2p.sendStringToSocket(
        jsonEncode({
          'type': 'meta',
          'index': i,
          'name': item.name,
          'size': fileSize,
          'total': files.length,
        }),
      );

      await Future.delayed(const Duration(milliseconds: 150));

      int sent = 0;
      DateTime lastUpdate = DateTime.now();
      int lastBytes = 0;

      await for (final chunk in file.openRead()) {
        if (!mounted) break;
        for (int offset = 0; offset < chunk.length; offset += chunkSize) {
          final end = (offset + chunkSize).clamp(0, chunk.length);
          _p2p.sendStringToSocket(base64Encode(chunk.sublist(offset, end)));
          sent += end - offset;

          final now = DateTime.now();
          if (now.difference(lastUpdate).inMilliseconds > 300) {
            final secs = now.difference(lastUpdate).inMilliseconds / 1000.0;
            final speed = (sent - lastBytes) / (1024 * 1024 * secs);
            final prog = fileSize > 0 ? sent / fileSize : 0.0;
            if (mounted) {
              state = state.copyWith(
                currentFileIndex: i,
                currentFileProgress: prog,
                overallProgress: (i + prog) / files.length,
                speedMBs: speed,
              );
            }
            lastUpdate = now;
            lastBytes = sent;
          }
        }
      }

      _p2p.sendStringToSocket(jsonEncode({'type': 'done', 'index': i}));

      if (mounted) {
        state = state.copyWith(
          currentFileIndex: i,
          currentFileProgress: 1.0,
          overallProgress: (i + 1) / files.length,
        );
      }

      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted)
      state = state.copyWith(isCompleted: true, overallProgress: 1.0);
  }

  // ── RECEIVER ───────────────────────────────────────────────────────────────

  Future<void> startReceiving(
    String groupOwnerAddress,
    bool isGroupOwner,
  ) async {
    state = TransferState(files: [], isSending: false);

    await Directory(_saveDir).create(recursive: true);
    _rxFileIndex = 0;
    _rxFiles = [];
    _sink = null;
    _expectedBytes = 0;
    _receivedBytes = 0;

    bool connected = false;
    if (isGroupOwner) {
      connected = await _p2p.startSocket(
        groupOwnerAddress: _goIp,
        onConnect: (_) =>
            _p2p.sendStringToSocket(jsonEncode({'type': 'ready'})),
        onRequest: (data) => _onReceiverMessage(data),
      );
    } else {
      for (int i = 0; i < 8 && !connected; i++) {
        connected = await _p2p.connectToSocket(
          groupOwnerAddress: _goIp,
          onConnect: (_) =>
              _p2p.sendStringToSocket(jsonEncode({'type': 'ready'})),
          onRequest: (data) => _onReceiverMessage(data),
        );
        if (!connected) await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!connected && mounted) {
      state = state.copyWith(error: 'Could not connect to sender socket.');
    }
  }

  void _onReceiverMessage(dynamic data) {
    if (data is! String) return;

    // Try JSON control message first
    try {
      final msg = jsonDecode(data);
      final type = msg['type'] as String?;

      if (type == 'meta') {
        _rxFileIndex = msg['index'] as int;
        final name = msg['name'] as String;
        final size = msg['size'] as int;
        final total = msg['total'] as int;

        _expectedBytes = size;
        _receivedBytes = 0;
        _lastSpeedTime = DateTime.now();
        _lastSpeedBytes = 0;

        final item = FileItem(
          id: name,
          name: name,
          sizeMB: size / (1024 * 1024),
          type: _inferType(name),
          path: '$_saveDir/$name',
        );

        final updated = List<FileItem>.from(state.files);
        if (_rxFileIndex >= updated.length) {
          updated.add(item);
        } else {
          updated[_rxFileIndex] = item;
        }
        _rxFiles = updated;

        if (mounted) {
          state = state.copyWith(
            files: updated,
            currentFileIndex: _rxFileIndex,
            currentFileProgress: 0.0,
            overallProgress: total > 0 ? _rxFileIndex / total : 0.0,
          );
        }

        _sink?.close();
        _sink = File('$_saveDir/$name').openWrite();
        return;
      }

      if (type == 'done') {
        final idx = msg['index'] as int;
        final total = _rxFiles.length;
        final filePath = '$_saveDir/${_rxFiles[idx].name}';

        _sink?.close();
        _sink = null;

        // Notify Android MediaStore so the file appears in gallery immediately
        _notifyMediaStore(filePath);

        if (mounted) {
          state = state.copyWith(
            currentFileIndex: idx,
            currentFileProgress: 1.0,
            overallProgress: total > 0 ? (idx + 1) / total : 1.0,
            isCompleted: idx == total - 1,
          );
        }
        return;
      }
    } catch (_) {
      // Not a JSON control message — fall through to base64 chunk handling
    }

    // base64-encoded file chunk
    try {
      final bytes = base64Decode(data);
      _sink?.add(bytes);
      _receivedBytes += bytes.length;

      final now = DateTime.now();
      if (now.difference(_lastSpeedTime).inMilliseconds > 300) {
        final secs = now.difference(_lastSpeedTime).inMilliseconds / 1000.0;
        final speed = (_receivedBytes - _lastSpeedBytes) / (1024 * 1024 * secs);
        final prog = _expectedBytes > 0 ? _receivedBytes / _expectedBytes : 0.0;
        final total = _rxFiles.length;

        if (mounted) {
          state = state.copyWith(
            currentFileProgress: prog,
            overallProgress: total > 0 ? (_rxFileIndex + prog) / total : 0.0,
            speedMBs: speed,
          );
          _p2p.sendStringToSocket(
            jsonEncode({
              'type': 'progress',
              'overall': total > 0 ? (_rxFileIndex + prog) / total : 0.0,
              'current': _rxFileIndex,
              'speed': speed,
            }),
          );
        }
        _lastSpeedTime = now;
        _lastSpeedBytes = _receivedBytes;
      }
    } catch (_) {}
  }

  /// Triggers Android's MediaScannerConnection so the file appears in gallery/Files
  void _notifyMediaStore(String filePath) {
    try {
      const MethodChannel(
        'datatransfer/media_scanner',
      ).invokeMethod<void>('scanFile', {'path': filePath});
    } catch (_) {}
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
