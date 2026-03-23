// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

import 'notification_configs.dart';
import 'notification_route.dart';

@pragma('vm:entry-point')
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static late NotificationRouter _router;

  static String firebaseToken = '';

  // 🚀 INITIALIZATION
  static Future<void> initialize(NotificationRouter router) async {
    _router = router;

    await Firebase.initializeApp();
    await _setupChannel();
    await _setupLocalNotifications();
    _setupFirebaseListeners();
    await _setupTokenHandling();

    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  }

  // 🔐 PERMISSION
  static Future<void> requestPermission(BuildContext context) async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
        await _fetchAndSaveToken();
        break;

      case AuthorizationStatus.denied:
        _showPermissionPopup(context);
        break;

      case AuthorizationStatus.provisional:
      default:
        break;
    }
  }

  // 📡 FIREBASE LISTENERS
  static void _setupFirebaseListeners() {
    // Foreground
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Background
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _router.handle(message.data),
    );

    // Terminated
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _router.handle(message.data);
      }
    });
  }

  // 🔔 SHOW NOTIFICATION
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final bigTextStyle = BigTextStyleInformation(
      notification.body ?? '',
      contentTitle: notification.title,
      htmlFormatBigText: true,
      htmlFormatContentTitle: true,
    );

    final androidDetails = AndroidNotificationDetails(
      NotificationConfig.channelId,
      NotificationConfig.channelName,
      channelDescription: NotificationConfig.channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: bigTextStyle,
      icon: NotificationConfig.appIcon,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: jsonEncode(message.data),
    );
  }

  // 👆 NOTIFICATION TAP
  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;

    final data = Map<String, dynamic>.from(jsonDecode(response.payload!));

    _router.handle(data);
  }

  // 🧱 LOCAL INIT
  static Future<void> _setupLocalNotifications() async {
    await _local.initialize(
      settings: InitializationSettings(
        android: AndroidInitializationSettings(NotificationConfig.appIcon),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  // 📣 ANDROID CHANNEL
  static Future<void> _setupChannel() async {
    if (!Platform.isAndroid) return;

    const channel = AndroidNotificationChannel(
      NotificationConfig.channelId,
      NotificationConfig.channelName,
      description: NotificationConfig.channelDescription,
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // 🔑 TOKEN HANDLING
  static Future<void> _setupTokenHandling() async {
    await _fetchAndSaveToken();

    _messaging.onTokenRefresh.listen((token) {
      firebaseToken = token;
      if (kDebugMode) {
        print('🔁 Token refreshed: $token');
      }
    });
  }

  static Future<void> _fetchAndSaveToken() async {
    firebaseToken = await _messaging.getToken() ?? '';
    if (kDebugMode) {
      print('🔥 FCM Token: $firebaseToken');
    }
  }

  // 🌙 BACKGROUND HANDLER
  @pragma('vm:entry-point')
  static Future<void> _backgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
  }

  // 🚨 PERMISSION POPUP
  static void _showPermissionPopup(BuildContext context) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return CupertinoAlertDialog(
          title: Text(
            'Permission Required',
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Please enable notifications from settings.',
            style: GoogleFonts.poppins(fontSize: 14.sp),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              child: const Text('Settings'),
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }
}
