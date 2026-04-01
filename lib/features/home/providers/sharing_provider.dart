import 'dart:async';
import 'dart:io';
import 'package:datatransfer/core/models/file_item.dart';
import 'package:datatransfer/features/file_selection/providers/selected_files_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharingIntentNotifier extends Notifier<List<FileItem>?> {
  @override
  List<FileItem>? build() => null;

  void setFiles(List<FileItem>? files) {
    state = files;
  }
}

final sharingIntentProvider = NotifierProvider<SharingIntentNotifier, List<FileItem>?>(() {
  return SharingIntentNotifier();
});

final sharingServiceProvider = Provider((ref) => SharingService(ref));

class SharingService {
  final Ref _ref;
  StreamSubscription? _intentDataStreamSubscription;
  bool _processedInitial = false;

  SharingService(this._ref);

  void init() {
    // For sharing images coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      _handleSharedMedia(value, isInitial: false);
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // For sharing images coming from outside the app while the app is closed
    if (!_processedInitial) {
      ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          _processedInitial = true;
          _handleSharedMedia(value, isInitial: true);
        }
      });
    }
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> files, {required bool isInitial}) async {
    if (files.isEmpty) return;

    final paths = files.map((f) => f.path).join('|');
    final prefs = await SharedPreferences.getInstance();
    
    if (isInitial) {
      final lastIntent = prefs.getString('last_handled_intent');
      if (lastIntent == paths) {
        print("SharingService: Skipping already handled initial intent.");
        return;
      }
    }
    
    // Track this intent as handled
    await prefs.setString('last_handled_intent', paths);

    final List<FileItem> fileItems = [];
    for (final file in files) {
      final ioFile = File(file.path);
      if (await ioFile.exists()) {
        final stat = await ioFile.stat();
        final name = file.path.split('/').last;
        
        fileItems.add(FileItem(
          id: file.path,
          name: name,
          path: file.path,
          sizeMB: stat.size / (1024 * 1024),
          type: _getFileType(file.path),
        ));
      }
    }

    if (fileItems.isNotEmpty) {
      // Update selected files
      final selectedNotifier = _ref.read(selectedFilesProvider.notifier);
      selectedNotifier.clearFiles();
      for (final item in fileItems) {
        selectedNotifier.toggleFile(item);
      }
      
      // Notify UI to navigate
      _ref.read(sharingIntentProvider.notifier).setFiles(fileItems);
    }
  }

  String _getFileType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'Photo';
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return 'Video';
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'flac':
        return 'Music';
      case 'apk':
        return 'App';
      default:
        return 'File';
    }
  }
}
