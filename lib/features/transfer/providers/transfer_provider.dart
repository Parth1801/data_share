import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:datatransfer/features/transfer/models/partial_transfer.dart';
import 'package:datatransfer/features/transfer/providers/transfer_storage_provider.dart';
import '../../../../core/models/file_item.dart';
import '../../home/models/history_item.dart';
import '../../home/providers/history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransferState {
  final List<FileItem> files;
  final double overallProgress;
  final double currentFileProgress;
  final int currentFileIndex;
  final double speedMBs;
  final bool isCompleted;
  final bool isSending;
  final bool isPaused;
  final String? error;

  bool get isTransferring => !isCompleted && files.isNotEmpty && error == null && !isPaused;

  TransferState({
    required this.files,
    this.overallProgress = 0.0,
    this.currentFileProgress = 0.0,
    this.currentFileIndex = 0,
    this.speedMBs = 0.0,
    this.isCompleted = false,
    this.isSending = false,
    this.isPaused = false,
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
    bool? isPaused,
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
      isPaused: isPaused ?? this.isPaused,
      error: error ?? this.error,
    );
  }
}

class TransferNotifier extends Notifier<TransferState> {
  @override
  TransferState build() {
    // In Notifier, we don't need to dispose manually usually, 
    // but for socket/sink we must handle it. 
    // We can use ref.onDispose for that.
    ref.onDispose(() {
      _cleanupPartial();
      _p2p.closeSocket();
      _sink?.close();
    });
    return TransferState(files: []);
  }

  final _p2p = FlutterP2pConnection();
  static const String _goIp = '192.168.49.1';
  static const String _saveDir = '/storage/emulated/0/Download/DataTransfer';

  // Receiver-side state
  IOSink? _sink;
  int _expectedBytes = 0;
  int _receivedBytes = 0;
  int _rxFileIndex = 0;
  List<FileItem> _rxFiles = [];
  DateTime _lastSpeedTime = DateTime.now();
  int _lastSpeedBytes = 0;
  
  // Resumable state
  Completer<int>? _readyOffsetCompleter;

  void cancelTransfer() {
    print('TransferNotifier: Explicit cancellation requested.');
    if (state.isSending) {
      try {
        _p2p.sendStringToSocket('cancel');
      } catch (e) {
        print('Error sending cancel message: $e');
      }
    }
    reset();
  }

  void reset() {
    _p2p.closeSocket();
    _sink?.close();
    _sink = null;
    state = TransferState(files: []);
  }

  void _cleanupPartial() {
    if (!state.isSending && _sink != null && _rxFiles.isNotEmpty && _rxFileIndex < _rxFiles.length) {
      final file = _rxFiles[_rxFileIndex];
      final id = "${file.name}_${_expectedBytes}";
      ref.read(transferStorageProvider).savePartialTransfer(PartialTransfer(
        id: id,
        name: file.name,
        totalSize: _expectedBytes,
        receivedBytes: _receivedBytes,
        path: file.path,
        updatedAt: DateTime.now(),
      ));
    }
  }

  // ── SENDER ─────────────────────────────────────────────────────────────────

  Future<void> startSending(
    List<FileItem> files,
    String groupOwnerAddress,
    bool isGroupOwner,
  ) async {
    state = TransferState(files: files, isSending: true);

    final connectionCompleter = Completer<void>();
    _readyOffsetCompleter = null;

    bool connected = false;
    if (isGroupOwner) {
      connected = await _p2p.startSocket(
        groupOwnerAddress: _goIp,
        onConnect: (_) {},
        onRequest: (data) => _onSenderMessage(data, connectionCompleter),
      );
    } else {
      for (int i = 0; i < 8 && !connected; i++) {
        connected = await _p2p.connectToSocket(
          groupOwnerAddress: _goIp,
          onConnect: (_) {},
          onRequest: (data) => _onSenderMessage(data, connectionCompleter),
        );
        if (!connected) await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!connected) {
      state = state.copyWith(error: 'Could not establish socket connection.');
      return;
    }

    try {
      await connectionCompleter.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      state = state.copyWith(error: 'Receiver did not respond in time.');
      return;
    }

    await _sendFiles(files);
  }

  void _onSenderMessage(dynamic data, Completer<void> connectionCompleter) {
    if (data is! String) return;
    
    if (data == 'cancel') {
      print('TransferNotifier: Receiver requested cancellation/cleanup.');
      reset();
      return;
    }

    try {
      final msg = jsonDecode(data);
      final type = msg['type'] as String?;

      if (type == 'ready') {
        if (!connectionCompleter.isCompleted) {
          connectionCompleter.complete();
        }
        if (_readyOffsetCompleter != null && !_readyOffsetCompleter!.isCompleted) {
          _readyOffsetCompleter!.complete(msg['offset'] as int? ?? 0);
        }
      } else if (msg['type'] == 'progress') {
        state = state.copyWith(
          overallProgress: (msg['overall'] as num?)?.toDouble() ?? 0.0,
          currentFileIndex: msg['current'] ?? 0,
          speedMBs: (msg['speed'] as num?)?.toDouble() ?? 0.0,
          isPaused: false,
        );
      } else if (msg['type'] == 'ping') {
        _p2p.sendStringToSocket(jsonEncode({'type': 'pong'}));
      }
    } catch (_) {}
  }

  Future<void> _sendFiles(List<FileItem> files) async {
    const chunkSize = 128 * 1024;

    try {
      for (int i = 0; i < files.length; i++) {
        if (!state.isTransferring) break;
        final item = files[i];
        final file = File(item.path);

        if (item.path.isEmpty || !await file.exists()) {
          state = state.copyWith(error: 'File not found: ${item.name}');
          return;
        }

        final fileSize = await file.length();
        _readyOffsetCompleter = Completer<int>();

        _p2p.sendStringToSocket(jsonEncode({
          'type': 'meta',
          'index': i,
          'name': item.name,
          'size': fileSize,
          'total': files.length,
        }));

        int offset = 0;
        try {
          offset = await _readyOffsetCompleter!.future.timeout(const Duration(seconds: 10));
        } catch (e) {
          print("Sender: Ready timeout, starting from 0. $e");
        }

        int sent = offset;
        DateTime lastUpdate = DateTime.now();
        int lastBytes = sent;

        await for (final chunk in file.openRead(offset)) {
          if (!state.isTransferring) break;
          
          for (int chunkOffset = 0; chunkOffset < chunk.length; chunkOffset += chunkSize) {
            final end = (chunkOffset + chunkSize).clamp(0, chunk.length);
            final subChunk = chunk.sublist(chunkOffset, end);
            
            _p2p.sendStringToSocket(base64Encode(subChunk));
            sent += subChunk.length;

            if (sent % (chunkSize * 16) == 0) {
              await Future.delayed(const Duration(milliseconds: 5));
            }

            final now = DateTime.now();
            if (now.difference(lastUpdate).inMilliseconds > 500) {
              final secs = now.difference(lastUpdate).inMilliseconds / 1000.0;
              final speed = (sent - lastBytes) / (1024 * 1024 * secs);
              final prog = fileSize > 0 ? sent / fileSize : 0.0;
              state = state.copyWith(
                currentFileIndex: i,
                currentFileProgress: prog,
                overallProgress: (i + prog) / files.length,
                speedMBs: speed,
              );
              lastUpdate = now;
              lastBytes = sent;
            }
          }
        }

        if (!state.isTransferring) break;

        _p2p.sendStringToSocket(jsonEncode({'type': 'done', 'index': i}));

        ref.read(historyProvider.notifier).addHistoryItem(HistoryItem(
          id: item.id,
          name: item.name,
          path: item.path,
          sizeMB: item.sizeMB,
          type: item.type,
          timestamp: DateTime.now(),
          isSent: true,
        ));

        state = state.copyWith(
          currentFileIndex: i,
          currentFileProgress: 1.0,
          overallProgress: (i + 1) / files.length,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!state.isPaused) {
        state = state.copyWith(isCompleted: true, overallProgress: 1.0);
      }
    } catch (e) {
      state = state.copyWith(isPaused: true, error: "Connection Lost.");
    }
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
        onConnect: (_) => _p2p.sendStringToSocket(jsonEncode({'type': 'ready'})),
        onRequest: (data) => _onReceiverMessage(data),
      );
    } else {
      for (int i = 0; i < 8 && !connected; i++) {
        connected = await _p2p.connectToSocket(
          groupOwnerAddress: _goIp,
          onConnect: (_) => _p2p.sendStringToSocket(jsonEncode({'type': 'ready'})),
          onRequest: (data) => _onReceiverMessage(data),
        );
        if (!connected) await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!connected) {
      state = state.copyWith(error: 'Could not connect to sender socket.');
    }
  }

  void _onReceiverMessage(dynamic data) async {
    if (data is! String) return;

    if (data == 'cancel') {
      print('TransferNotifier: Cancellation signal received from sender.');
      if (_sink != null) {
        await _sink!.close();
        _sink = null;
      }
      if (_rxFiles.isNotEmpty && _rxFileIndex < _rxFiles.length) {
        final item = _rxFiles[_rxFileIndex];
        final file = File('$_saveDir/${item.name}');
        if (await file.exists()) {
          await file.delete();
          print('TransferNotifier: Deleted cancelled partial file: ${file.path}');
        }
        await ref.read(transferStorageProvider).clearPartialTransfer(item.name);
      }
      reset();
      return;
    }

    if (data.startsWith('{')) {
      try {
        final msg = jsonDecode(data);
        final type = msg['type'] as String?;

        if (type == 'meta') {
          _rxFileIndex = msg['index'] as int;
          final name = msg['name'] as String;
          final size = msg['size'] as int;
          final total = msg['total'] as int;

          _expectedBytes = size;
          
          final id = "${name}_$size";
          final partial = await ref.read(transferStorageProvider).getPartialTransfer(id);
          _receivedBytes = partial?.receivedBytes ?? 0;
          
          _lastSpeedTime = DateTime.now();
          _lastSpeedBytes = _receivedBytes;

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

          state = state.copyWith(
            files: updated,
            currentFileIndex: _rxFileIndex,
            currentFileProgress: size > 0 ? _receivedBytes / size : 0.0,
            overallProgress: total > 0 ? (_rxFileIndex + (_receivedBytes / size)) / total : 0.0,
            isPaused: false,
          );

          _sink?.close();
          final file = File('$_saveDir/$name');
          if (_receivedBytes > 0 && await file.exists()) {
             _sink = file.openWrite(mode: FileMode.append);
          } else {
             _sink = file.openWrite();
             _receivedBytes = 0;
          }
          
          _p2p.sendStringToSocket(jsonEncode({'type': 'ready', 'offset': _receivedBytes}));
          return;
        }

        if (type == 'done') {
          final idx = msg['index'] as int;
          final total = _rxFiles.length;
          final filePath = '$_saveDir/${_rxFiles[idx].name}';

          _sink?.close();
          _sink = null;

          final id = "${_rxFiles[idx].name}_$_expectedBytes";
          await ref.read(transferStorageProvider).removePartialTransfer(id);

          _notifyMediaStore(filePath);

          final savedFile = _rxFiles[idx];
          ref.read(historyProvider.notifier).addHistoryItem(HistoryItem(
            id: savedFile.id,
            name: savedFile.name,
            path: savedFile.path,
            sizeMB: savedFile.sizeMB,
            type: savedFile.type,
            timestamp: DateTime.now(),
            isSent: false,
          ));

          state = state.copyWith(
            currentFileIndex: idx,
            currentFileProgress: 1.0,
            overallProgress: total > 0 ? (idx + 1) / total : 1.0,
            isCompleted: idx == total - 1,
          );
          return;
        }
      } catch (e) {
        print("Receiver Control Error: $e");
      }
    } else {
      // base64 chunk
      try {
        final bytes = base64Decode(data);
        _sink?.add(bytes);
        _receivedBytes += bytes.length;

        final now = DateTime.now();
        if (now.difference(_lastSpeedTime).inMilliseconds > 400) {
          final secs = now.difference(_lastSpeedTime).inMilliseconds / 1000.0;
          final speed = (_receivedBytes - _lastSpeedBytes) / (1024 * 1024 * secs);
          final prog = _expectedBytes > 0 ? _receivedBytes / _expectedBytes : 0.0;
          final total = _rxFiles.length;

          state = state.copyWith(
            currentFileProgress: prog,
            overallProgress: total > 0 ? (_rxFileIndex + prog) / total : 0.0,
            speedMBs: speed,
          );
          
          if (_receivedBytes - _lastSpeedBytes > 1024 * 1024) {
             final file = _rxFiles[_rxFileIndex];
              ref.read(transferStorageProvider).savePartialTransfer(PartialTransfer(
                id: "${file.name}_$_expectedBytes",
                name: file.name,
                totalSize: _expectedBytes,
                receivedBytes: _receivedBytes,
                path: '$_saveDir/${file.name}',
                updatedAt: now,
              ));
          }

          _p2p.sendStringToSocket(jsonEncode({
            'type': 'progress',
            'overall': total > 0 ? (_rxFileIndex + prog) / total : 0.0,
            'current': _rxFileIndex,
            'speed': speed,
          }));

          _lastSpeedTime = now;
          _lastSpeedBytes = _receivedBytes;
        }
      } catch (_) {}
    }
  }

  void _notifyMediaStore(String filePath) {
    try {
      const MethodChannel(
        'datatransfer/media_scanner',
      ).invokeMethod<void>('scanFile', {'path': filePath});
    } catch (_) {}
  }

  String _inferType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) return 'Photo';
    if (['mp4', 'mkv', 'avi', 'mov', 'webm'].contains(ext)) return 'Video';
    if (['mp3', 'aac', 'wav', 'flac', 'ogg'].contains(ext)) return 'Audio';
    return 'File';
  }
}

final transferProvider = NotifierProvider<TransferNotifier, TransferState>(() {
  return TransferNotifier();
});
