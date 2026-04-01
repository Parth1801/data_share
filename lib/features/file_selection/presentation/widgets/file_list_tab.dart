import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:installed_apps/app_info.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:datatransfer/core/models/file_item.dart';
import '../../providers/device_files_provider.dart';
import '../../providers/selected_files_provider.dart';
import 'dart:typed_data';

class FileListTab extends ConsumerWidget {
  final String type;
  final Function(FileItem) onToggleSelection;
  final bool isGrid;

  const FileListTab({
    super.key,
    required this.type,
    required this.onToggleSelection,
    this.isGrid = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (type) {
      case 'Apps':
        return _buildAsyncData(ref.watch(appsProvider), (data) => _buildAppsList(context, ref, data));
      case 'Photos':
        return _buildAsyncData(ref.watch(photosProvider), (data) => _buildMediaGrid(context, ref, data));
      case 'Videos':
        return _buildAsyncData(ref.watch(videosProvider), (data) => _buildMediaGrid(context, ref, data));
      case 'Music':
        return _buildAsyncData(ref.watch(audioProvider), (data) => _buildAudioList(context, ref, data));
      case 'Files':
        return _buildAsyncData(ref.watch(myFilesProvider), (data) => _buildFilesList(context, ref, data));
      case 'History':
      default:
        return const Center(child: Text('History implementation coming soon'));
    }
  }

  Widget _buildAsyncData<T>(AsyncValue<T> asyncValue, Widget Function(T) builder) {
    return asyncValue.when(
      data: (data) {
        if (data is List && data.isEmpty) {
          return Center(child: Text('No $type found'));
        }
        return builder(data);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildAppsList(BuildContext context, WidgetRef ref, List<AppInfo> apps) {
    final selectedFiles = ref.watch(selectedFilesProvider);
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 100.h),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final fileItem = FileItem(
          id: app.packageName,
          name: app.name,
          path: app.packageName, // Apps don't have a simple single file path for sharing APK usually without extra steps
          sizeMB: 0,
          type: 'App',
        );
        final isSelected = selectedFiles.any((item) => item.id == fileItem.id);

        return ListTile(
          leading: app.icon != null 
              ? Image.memory(app.icon!, width: 45.w, height: 45.w) 
              : Icon(Icons.android, size: 45.w, color: Theme.of(context).primaryColor),
          title: Text(app.name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
          subtitle: Text(app.versionName, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
          trailing: IconButton(
            icon: Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade400,
            ),
            onPressed: () => onToggleSelection(fileItem),
          ),
          onTap: () => onToggleSelection(fileItem),
        );
      },
    );
  }

  Widget _buildMediaGrid(BuildContext context, WidgetRef ref, List<AssetEntity> mediaItems) {
    final selectedFiles = ref.watch(selectedFilesProvider);
    return GridView.builder(
      padding: EdgeInsets.only(left: 10.w, right: 10.w, top: 10.h, bottom: 100.h),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
      ),
      itemCount: mediaItems.length,
      itemBuilder: (context, index) {
        final entity = mediaItems[index];
        final fileItem = FileItem(
          id: entity.id,
          name: entity.title ?? 'Media ${entity.id}',
          path: entity.id, // For AssetEntity, we resolve the real path later using entity.file
          sizeMB: 0,
          type: type == 'Photos' ? 'Photo' : 'Video',
        );
        final isSelected = selectedFiles.any((item) => item.id == fileItem.id);

        return GestureDetector(
          onTap: () => onToggleSelection(fileItem),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 2) : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: FutureBuilder<Uint8List?>(
                    future: entity.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                        return Image.memory(snapshot.data!, fit: BoxFit.cover);
                      }
                      return Icon(
                        type == 'Photos' ? Icons.image : Icons.video_library,
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                        size: 40.sp,
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 5.h,
                  right: 5.w,
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                    size: 20.sp,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioList(BuildContext context, WidgetRef ref, List<SongModel> songs) {
    final selectedFiles = ref.watch(selectedFilesProvider);
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 100.h),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final fileItem = FileItem(
          id: song.id.toString(),
          name: song.title,
          path: song.data,
          sizeMB: (song.size / (1024 * 1024)).toDouble(),
          type: 'Music',
        );
        final isSelected = selectedFiles.any((item) => item.id == fileItem.id);

        return ListTile(
          leading: QueryArtworkWidget(
            id: song.id,
            type: ArtworkType.AUDIO,
            nullArtworkWidget: Icon(Icons.music_note, size: 45.w, color: Theme.of(context).primaryColor),
          ),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
          subtitle: Text(song.artist ?? 'Unknown Artist', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
          trailing: IconButton(
            icon: Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade400,
            ),
            onPressed: () => onToggleSelection(fileItem),
          ),
          onTap: () => onToggleSelection(fileItem),
        );
      },
    );
  }

  Widget _buildFilesList(BuildContext context, WidgetRef ref, List<File> files) {
    final selectedFiles = ref.watch(selectedFilesProvider);
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 100.h),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final name = file.path.split('/').last;
        final fileItem = FileItem(
          id: file.path,
          name: name,
          path: file.path,
          sizeMB: 0,
          type: 'File',
        );
        final isSelected = selectedFiles.any((item) => item.id == fileItem.id);

        return ListTile(
          leading: Icon(Icons.insert_drive_file, size: 45.w, color: Theme.of(context).primaryColor),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
          subtitle: FutureBuilder<int>(
            future: file.length(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final mb = snapshot.data! / (1024 * 1024);
                return Text('${mb.toStringAsFixed(2)} MB', style: TextStyle(fontSize: 12.sp, color: Colors.grey));
              }
              return const Text('Loading...');
            },
          ),
          trailing: IconButton(
            icon: Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade400,
            ),
            onPressed: () => onToggleSelection(fileItem),
          ),
          onTap: () => onToggleSelection(fileItem),
        );
      },
    );
  }
}
