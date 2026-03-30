import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static final SharedPrefsService _instance = SharedPrefsService._internal();
  factory SharedPrefsService() => _instance;
  SharedPrefsService._internal();

  late final SharedPreferences _prefs;

  static const String _isDarkModeKey = 'isDarkMode';
  static const String _userKey = 'logged_in_user';

  /// Initialize the SharedPreferences instance
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Theme ---
  bool get isDarkMode => _prefs.getBool(_isDarkModeKey) ?? false;
  Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool(_isDarkModeKey, isDark);
  }

  // --- User Session ---
  String? get userJson => _prefs.getString(_userKey);
  Future<void> setUserJson(String json) async {
    await _prefs.setString(_userKey, json);
  }

  bool get hasUser => _prefs.containsKey(_userKey);

  /// Clear all except theme preference (or clear all)
  Future<void> clearUserSession() async {
    await _prefs.remove(_userKey);
  }

  // --- Notifications ---
  bool get notificationsEnabled =>
      _prefs.getBool('notificationsEnabled') ?? true;
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool('notificationsEnabled', enabled);
  }

  // --- Authentication Token ---
  String? getUserToken() => _prefs.getString('auth_token');
  Future<void> setUserToken(String token) async {
    await _prefs.setString('auth_token', token);
  }

  Future<void> clearUserToken() async {
    await _prefs.remove('auth_token');
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
