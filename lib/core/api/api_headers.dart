import 'package:datatransfer/core/services/shared_prefs_service.dart';

/// Manages HTTP headers including authorization tokens
class ApiHeaders {
  /// Retrieves the authentication token from SharedPreferences
  static Future<String> getToken() async {
    return SharedPrefsService().getUserToken() ?? '';
  }

  /// Default headers for JSON requests
  static Future<Map<String, String>> get defaultHeaders async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Headers for multipart form data requests
  static Future<Map<String, String>> get multipartHeaders async {
    final token = await getToken();
    return {if (token.isNotEmpty) 'Authorization': 'Bearer $token'};
  }
}
