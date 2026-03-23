/// Per-project notification configuration
class NotificationConfig {
  // 🔔 Notification Channel
  static const String channelId = 'default_channel';
  static const String channelName = 'App Notifications';
  static const String channelDescription = 'General notifications';

  // 🖼 App icon (Android)
  static const String appIcon = '@mipmap/ic_launcher';

  // 📦 Payload keys (must match backend)
  static const String keyScreen = 'screen';
  static const String keyRoute = 'route';
  static const String keyArguments = 'arguments';
}
