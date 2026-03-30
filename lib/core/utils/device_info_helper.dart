import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoHelper {
  static Future<String> getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.model; // e.g., "SM-G998B" or "Pixel 7"
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name; // e.g., "Parth's iPhone"
      } else if (Platform.isWindows) {
        // Since you are using Windows, we can grab the PC name too!
        final windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.computerName;
      }
    } catch (e) {
      return 'Unknown Device';
    }

    return 'Unknown Device';
  }
}
