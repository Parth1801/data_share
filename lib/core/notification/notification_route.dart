/// Every project must implement this
abstract class NotificationRouter {
  /// Called when:
  /// - Notification tapped
  /// - App opened from terminated state
  /// - Foreground notification clicked
  Future<void> handle(Map<String, dynamic> data);
}


/*
how to use 

import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'notification_config.dart';
import 'notification_route.dart';
import '../../main_screen/main_screen.dart';
import '../../core/constants/notification_screen_type.dart';

class AppNotificationRouter implements NotificationRouter {
  @override
  Future<void> handle(Map<String, dynamic> data) async {
    // 🧪 Debug while testing
    // debugPrint('🔔 Notification data: $data');

    final screen = data[NotificationConfig.keyScreen];
    if (screen == null) return;

    final box = await Hive.openBox('notification_nav');

    // 🔥 Clear previous intent
    await box.delete('nav');
    await box.delete('category_id');
    await box.delete('category_name');
    await box.delete('pending_tab');

    switch (screen) {
      case NotificationScreenType.mybusiness:
        await box.put('nav', 'business');
        break;

      case NotificationScreenType.profile:
        await box.put('pending_tab', 4);
        break;

      case NotificationScreenType.branding:
        await box.put('pending_tab', 0);

        if (data['category_id'] != null &&
            data['category_name'] != null) {
          await box.put('nav', 'branding');
          await box.put('category_id', data['category_id']);
          await box.put('category_name', data['category_name']);
        }
        break;

      case NotificationScreenType.directory:
        await box.put('pending_tab', 1);
        break;
    }

    // 🚀 Always land on MainScreen
    Get.offAll(() => const MainScreen());
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.initialize(
    AppNotificationRouter(), // 🔥 THIS WIRES handle()
  );

  await NotificationService.requestPermission();

  runApp(const MyApp());
}


*/