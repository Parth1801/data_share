// import 'dart:io';

// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/data/latest_all.dart' as tzdata;
// import 'package:timezone/timezone.dart' as tz;
// import 'package:todo_app_riverpod/core/services/shared_prefs_service.dart';
// import 'package:todo_app_riverpod/view/todo/data/models/todo_model.dart';

// class NotificationService {
//   NotificationService._();
//   static final NotificationService instance = NotificationService._();

//   final FlutterLocalNotificationsPlugin _plugin =
//       FlutterLocalNotificationsPlugin();

//   bool _initialized = false;

//   Future<bool> requestPermissions() async {
//     bool? grantedAndroid = true;
//     bool? grantedIOS = true;

//     if (Platform.isAndroid) {
//       final androidImpl = _plugin.resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin>();
//       grantedAndroid = await androidImpl?.requestNotificationsPermission();
//     } else if (Platform.isIOS) {
//       final iosImpl = _plugin.resolvePlatformSpecificImplementation<
//           IOSFlutterLocalNotificationsPlugin>();
//       grantedIOS = await iosImpl?.requestPermissions(
//         alert: true,
//         badge: true,
//         sound: true,
//       );
//     }

//     return (grantedAndroid ?? false) && (grantedIOS ?? false);
//   }

//   Future<void> requestExactAlarmPermission() async {
//     if (!Platform.isAndroid) return;

//     final androidImpl = _plugin
//         .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin
//         >();
//     await androidImpl?.requestExactAlarmsPermission();
//   }

//   Future<void> init() async {
//     if (_initialized) return;

//     print("🔔 NotificationService initialized");

//     tzdata.initializeTimeZones();

//     const android = AndroidInitializationSettings('@mipmap/ic_launcher');

//     const ios = DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );

//     const settings = InitializationSettings(android: android, iOS: ios);

//     await _plugin.initialize(
//       settings: settings,
//       onDidReceiveNotificationResponse: (NotificationResponse response) {
//         print('🔔 Notification payload: ${response.payload}');
//       },
//     );

//     const highChannel = AndroidNotificationChannel(
//       'high_priority_channel',
//       'High Priority Tasks',
//       description: 'Notifications for urgent tasks',
//       importance: Importance.max,
//       playSound: true,
//       sound: RawResourceAndroidNotificationSound('urgent_sound'),
//       enableVibration: true,
//     );

//     const lowChannel = AndroidNotificationChannel(
//       'low_priority_channel',
//       'Low Priority Tasks',
//       description: 'Notifications for regular tasks',
//       importance: Importance.max,
//       playSound: true,
//       sound: RawResourceAndroidNotificationSound('normal_sound'),
//     );

//     await _plugin
//         .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin
//         >()
//         ?.createNotificationChannel(highChannel);

//     await _plugin
//         .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin
//         >()
//         ?.createNotificationChannel(lowChannel);

//     // The original 'trip_channel_id' is removed as it's replaced by priority channels
//     // const channel = AndroidNotificationChannel(
//     //   'trip_channel_id',
//     //   'Trip Reminders',
//     //   description: 'Reminders and FCM notifications',
//     //   importance: Importance.max,
//     // );
//     // await _plugin
//     //     .resolvePlatformSpecificImplementation<
//     //       AndroidFlutterLocalNotificationsPlugin
//     //     >()
//     //     ?.createNotificationChannel(channel);

//     _initialized = true;
//   }

//   Future<void> scheduleNotification({
//     required String id,
//     required String title,
//     required String body,
//     required DateTime scheduledTime,
//     String? payload,
//     String priority = 'Low',
//   }) async {
//     if (!_initialized) await init();

//     // 🛑 Check preference
//     final areNotificationsEnabled = SharedPrefsService().notificationsEnabled;
//     if (!areNotificationsEnabled) return;

//     if (scheduledTime.isBefore(DateTime.now())) return;

//     final int notificationId = id.hashCode.abs();
//     final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

//     final androidImpl = _plugin
//         .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin
//         >();

//     // 🔐 CHECK exact alarm permission
//     final bool canUseExact =
//         await androidImpl?.canScheduleExactNotifications() ?? false;

//     await _plugin.zonedSchedule(
//       id: notificationId,
//       title: title,
//       body: body,
//       scheduledDate: tzScheduled,
//       notificationDetails: NotificationDetails(
//         android: AndroidNotificationDetails(
//           priority == 'High' ? 'high_priority_channel' : 'low_priority_channel',
//           priority == 'High' ? 'High Priority Tasks' : 'Low Priority Tasks',
//           channelDescription: priority == 'High'
//               ? 'Notifications for urgent tasks'
//               : 'Notifications for regular tasks',
//           importance: priority == 'High'
//               ? Importance.max
//               : Importance.defaultImportance,
//           priority: priority == 'High'
//               ? Priority.high
//               : Priority.defaultPriority,
//           icon: '@mipmap/ic_launcher',
//           enableVibration: priority == 'High',
//         ),
//         iOS: DarwinNotificationDetails(
//           presentSound: true,
//           sound: priority == 'High' ? 'urgent_sound.aiff' : 'normal_sound.aiff',
//         ),
//       ),
//       payload: payload,

//       // ✅ SAFE scheduling mode
//       androidScheduleMode: canUseExact
//           ? AndroidScheduleMode.exactAllowWhileIdle
//           : AndroidScheduleMode.inexactAllowWhileIdle,
//     );
//   }

//   Future<void> cancelNotification(String id) async {
//     final int notificationId = id.hashCode.abs();
//     await _plugin.cancel(
//       id: notificationId,
//     ); // Changed 'id' to 'notificationId'
//   }

//   Future<void> cancelAll() async {
//     await _plugin.cancelAll();
//   }

//   bool isFutureTodo(Todo todo) {
//     try {
//       final dateTime = DateTime.parse("${todo.date} ${todo.time}");
//       return dateTime.isAfter(DateTime.now());
//     } catch (_) {
//       return false;
//     }
//   }

//   Future<void> scheduleTodo(Todo todo) async {
//     final dateTime = DateTime.parse("${todo.date} ${todo.time}");

//     await scheduleNotification(
//       id: todo.id,
//       title: "Todo Reminder",
//       body: todo.title,
//       scheduledTime: dateTime,
//       priority: todo.priority == 'High' ? 'High' : 'Low',
//       payload: todo.id,
//     );
//   }
// }
