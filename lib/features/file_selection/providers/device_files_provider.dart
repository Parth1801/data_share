import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:on_audio_query/on_audio_query.dart';

// 1. Apps Provider
final appsProvider = FutureProvider<List<AppInfo>>((ref) async {
  List<AppInfo> apps = await InstalledApps.getInstalledApps(
    excludeSystemApps: true,
    withIcon: true,
  );
  return apps;
});

// 2. Photos Provider
final photosProvider = FutureProvider<List<AssetEntity>>((ref) async {
  final PermissionState ps = await PhotoManager.requestPermissionExtend();
  if (ps.isAuth || ps.hasAccess) {
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );
    if (albums.isNotEmpty) {
      // Get the first album (Usually "Recent")
      return await albums[0].getAssetListPaged(page: 0, size: 200);
    }
  }
  return [];
});

// 3. Videos Provider
final videosProvider = FutureProvider<List<AssetEntity>>((ref) async {
  final PermissionState ps = await PhotoManager.requestPermissionExtend();
  if (ps.isAuth || ps.hasAccess) {
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
    );
    if (albums.isNotEmpty) {
      return await albums[0].getAssetListPaged(page: 0, size: 200);
    }
  }
  return [];
});

// 4. Music Provider
final audioProvider = FutureProvider<List<SongModel>>((ref) async {
  final OnAudioQuery audioQuery = OnAudioQuery();
  bool permissionStatus = await audioQuery.permissionsStatus();
  if (!permissionStatus) {
    await audioQuery.permissionsRequest();
  }
  return await audioQuery.querySongs(
    sortType: null,
    orderType: OrderType.ASC_OR_SMALLER,
    uriType: UriType.EXTERNAL,
    ignoreCase: true,
  );
});

// 5. Files Provider (Downloads directory as a sample)
final myFilesProvider = FutureProvider<List<File>>((ref) async {
  final dir = Directory('/storage/emulated/0/Download');
  if (await dir.exists()) {
    final entities = await dir.list().toList();
    return entities.whereType<File>().toList();
  }
  return [];
});
