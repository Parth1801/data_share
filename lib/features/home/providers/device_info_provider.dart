import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deviceNameProvider = FutureProvider<String>((ref) async {
  final deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.model;
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfo.iosInfo;
    return iosInfo.name;
  } else if (Platform.isWindows) {
    final windowsInfo = await deviceInfo.windowsInfo;
    return windowsInfo.computerName;
  }
  return 'My Device';
});
