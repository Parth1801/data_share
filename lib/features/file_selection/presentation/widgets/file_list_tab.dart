import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:installed_apps/app_info.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../providers/device_files_provider.dart';
import 'dart:typed_data';

class FileListTab extends ConsumerWidget {
  final String type;
  final VoidCallback onToggleSelection;
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
        return _buildAsyncData(ref.watch(appsProvider), (data) => _buildAppsList(context, data));
      case 'Photos':
        return _buildAsyncData(ref.watch(photosProvider), (data) => _buildMediaGrid(context, data));
      case 'Videos':
        return _buildAsyncData(ref.watch(videosProvider), (data) => _buildMediaGrid(context, data));
      case 'Music':
        return _buildAsyncData(ref.watch(audioProvider), (data) => _buildAudioList(context, data));
      case 'Files':
        return _buildAsyncData(ref.watch(myFilesProvider), (data) => _buildFilesList(context, data));
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

  Widget _buildAppsList(BuildContext context, List<AppInfo> apps) {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 100.h),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return ListTile(
          leading: app.icon != null 
              ? Image.memory(app.icon!, width: 45.w, height: 45.w) 
              : Icon(Icons.android, size: 45.w, color: Theme.of(context).primaryColor),
          title: Text(app.name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
          subtitle: Text(app.versionName, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
          trailing: IconButton(
            icon: Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400),
            onPressed: onToggleSelection,
          ),
          onTap: onToggleSelection,
        );
      },
    );
  }

  Widget _buildMediaGrid(BuildContext context, List<AssetEntity> mediaItems) {
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
        return GestureDetector(
          onTap: onToggleSelection,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
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
                  child: Icon(Icons.radio_button_unchecked, color: Colors.white, size: 20.sp),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioList(BuildContext context, List<SongModel> songs) {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 100.h),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return ListTile(
          leading: QueryArtworkWidget(
            id: song.id,
            type: ArtworkType.AUDIO,
            nullArtworkWidget: Icon(Icons.music_note, size: 45.w, color: Theme.of(context).primaryColor),
          ),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
          subtitle: Text(song.artist ?? 'Unknown Artist', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
          trailing: IconButton(
            icon: Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400),
            onPressed: onToggleSelection,
          ),
          onTap: onToggleSelection,
        );
      },
    );
  }

  Widget _buildFilesList(BuildContext context, List<File> files) {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 100.h),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return ListTile(
          leading: Icon(Icons.insert_drive_file, size: 45.w, color: Theme.of(context).primaryColor),
          title: Text(file.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
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
            icon: Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400),
            onPressed: onToggleSelection,
          ),
          onTap: onToggleSelection,
        );
      },
    );
  }
}
