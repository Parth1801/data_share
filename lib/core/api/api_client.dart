import 'dart:convert';
import 'package:datatransfer/core/api/api_headers.dart';
import 'package:datatransfer/core/api/api_response.dart';
import 'package:datatransfer/core/constants/app_strings.dart';
import 'package:datatransfer/core/services/loading_service.dart';
import 'package:datatransfer/shared/utils/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Professional API service class for handling HTTP requests
class ApiClient {
  static bool isLoading = false;

  static Uri _buildUri(String url, [Map<String, dynamic>? queryParams]) {
    return Uri.parse(url).replace(queryParameters: queryParams);
  }

  /// Performs GET request
  static Future<ApiResponse<T>> get<T>({
    required BuildContext context,
    required String url,
    required String dialogTitle,
    bool showDialog = true,
    Map<String, dynamic>? queryParams,
    T Function(Map<String, dynamic>)? parseModel,
    bool showLoading = true,
    VoidCallback? callback,
  }) async {
    isLoading = true;
    if (showLoading) {
      try {
        showLoader(context);
      } catch (e) {
        debugPrint('Error showing loader: $e');
      }
    }

    try {
      final response = await http.get(
        _buildUri(url, queryParams),
        headers: await ApiHeaders.defaultHeaders,
      );

      return _handleResponse(
        context,
        dialogTitle,
        showDialog,
        response,
        parseModel,
        callback: callback,
      );
    } catch (e) {
      if (showDialog) {
        AppDialogs.showMessage(
          context: context,
          title: dialogTitle,
          message: e.toString(),
          positiveButton: DialogStrings.ok,
          callback: callback,
        );
      }
      return ApiResponse.error(e.toString());
    } finally {
      isLoading = false;
      if (showLoading) {
        try {
          await hideLoader();
        } catch (e) {
          debugPrint('Error hiding loader: $e');
        }
      }
    }
  }

  /// Performs POST request with JSON body
  static Future<ApiResponse<T>> post<T>({
    required BuildContext context,
    required String url,
    required String dialogTitle,
    bool showDialog = true,
    Map<String, dynamic>? body,
    T Function(Map<String, dynamic>)? parseModel,
    bool showLoading = true,
    VoidCallback? callback,
  }) async {
    isLoading = true;
    if (showLoading) {
      try {
        showLoader(context);
      } catch (e) {
        debugPrint('Error showing loader: $e');
      }
    }

    try {
      debugPrint('POST body: $body');
      final response = await http.post(
        Uri.parse(url),
        headers: await ApiHeaders.defaultHeaders,
        body: jsonEncode(body ?? {}),
      );

      debugPrint('POST response: ${response.body}');
      return _handleResponse(
        context,
        dialogTitle,
        showDialog,
        response,
        parseModel,
        callback: callback,
      );
    } catch (e) {
      if (showDialog) {
        AppDialogs.showMessage(
          context: context,
          title: dialogTitle,
          message: e.toString(),
          positiveButton: DialogStrings.ok,
          callback: callback,
        );
      }
      return ApiResponse.error(e.toString());
    } finally {
      isLoading = false;
      if (showLoading) {
        try {
          await hideLoader();
        } catch (e) {
          debugPrint('Error hiding loader: $e');
        }
      }
    }
  }

  /// Performs POST request with form data (no files)
  static Future<ApiResponse<T>> postFormData<T>({
    required BuildContext context,
    required String url,
    required String dialogTitle,
    bool showDialog = true,
    required Map<String, dynamic> fields,
    T Function(Map<String, dynamic>)? parseModel,
    bool showLoading = true,
    VoidCallback? callback,
  }) async {
    isLoading = true;
    if (showLoading) {
      try {
        showLoader(context);
      } catch (e) {
        debugPrint('Error showing loader: $e');
      }
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(await ApiHeaders.multipartHeaders);

      fields.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Form data response: ${response.body}');
      return _handleResponse(
        context,
        dialogTitle,
        showDialog,
        response,
        parseModel,
        callback: callback,
      );
    } catch (e) {
      if (showDialog) {
        AppDialogs.showMessage(
          context: context,
          title: dialogTitle,
          message: e.toString(),
          positiveButton: DialogStrings.ok,
          callback: callback,
        );
      }
      return ApiResponse.error(e.toString());
    } finally {
      isLoading = false;
      if (showLoading) {
        try {
          await hideLoader();
        } catch (e) {
          debugPrint('Error hiding loader: $e');
        }
      }
    }
  }

  /// Performs PUT request
  static Future<ApiResponse<T>> put<T>({
    required BuildContext context,
    required String url,
    required String dialogTitle,
    bool showDialog = true,
    Map<String, dynamic>? body,
    T Function(Map<String, dynamic>)? parseModel,
    bool showLoading = true,
    VoidCallback? callback,
  }) async {
    isLoading = true;
    if (showLoading) {
      try {
        showLoader(context);
      } catch (e) {
        debugPrint('Error showing loader: $e');
      }
    }

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: await ApiHeaders.defaultHeaders,
        body: jsonEncode(body ?? {}),
      );

      return _handleResponse(
        context,
        dialogTitle,
        showDialog,
        response,
        parseModel,
        callback: callback,
      );
    } catch (e) {
      if (showDialog) {
        AppDialogs.showMessage(
          context: context,
          title: dialogTitle,
          message: e.toString(),
          positiveButton: DialogStrings.ok,
          callback: callback,
        );
      }
      return ApiResponse.error(e.toString());
    } finally {
      isLoading = false;
      if (showLoading) {
        try {
          await hideLoader();
        } catch (e) {
          debugPrint('Error hiding loader: $e');
        }
      }
    }
  }

  /// Performs DELETE request
  static Future<ApiResponse<T>> delete<T>({
    required BuildContext context,
    required String url,
    required String dialogTitle,
    bool showDialog = true,
    Map<String, dynamic>? queryParams,
    T Function(Map<String, dynamic>)? parseModel,
    bool showLoading = true,
    VoidCallback? callback,
  }) async {
    isLoading = true;
    if (showLoading) {
      try {
        showLoader(context);
      } catch (e) {
        debugPrint('Error showing loader: $e');
      }
    }

    try {
      final response = await http.delete(
        _buildUri(url, queryParams),
        headers: await ApiHeaders.defaultHeaders,
      );

      return _handleResponse(
        context,
        dialogTitle,
        showDialog,
        response,
        parseModel,
        callback: callback,
      );
    } catch (e) {
      if (showDialog) {
        AppDialogs.showMessage(
          context: context,
          title: dialogTitle,
          message: e.toString(),
          positiveButton: DialogStrings.ok,
          callback: callback,
        );
      }
      return ApiResponse.error(e.toString());
    } finally {
      isLoading = false;
      if (showLoading) {
        try {
          await hideLoader();
        } catch (e) {
          debugPrint('Error hiding loader: $e');
        }
      }
    }
  }

  /// Performs multipart request with file uploads
  static Future<ApiResponse<T>> multipart<T>({
    required BuildContext context,
    required String url,
    required String dialogTitle,
    bool showDialog = true,
    required Map<String, String> fields,
    required Map<String, String> files,
    T Function(Map<String, dynamic>)? parseModel,
    bool showLoading = true,
    VoidCallback? callback,
  }) async {
    isLoading = true;
    if (showLoading) {
      try {
        showLoader(context);
      } catch (e) {
        debugPrint('Error showing loader: $e');
      }
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(await ApiHeaders.multipartHeaders);

      fields.forEach((key, value) => request.fields[key] = value);

      for (var entry in files.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(entry.key, entry.value),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Multipart response: ${response.body}');
      return _handleResponse(
        context,
        dialogTitle,
        showDialog,
        response,
        parseModel,
        callback: callback,
      );
    } catch (e) {
      if (showDialog) {
        AppDialogs.showMessage(
          context: context,
          title: dialogTitle,
          message: e.toString(),
          positiveButton: DialogStrings.ok,
          callback: callback,
        );
      }
      return ApiResponse.error(e.toString());
    } finally {
      isLoading = false;
      if (showLoading) {
        try {
          await hideLoader();
        } catch (e) {
          debugPrint('Error hiding loader: $e');
        }
      }
    }
  }

  /// Centralized response handler
  static ApiResponse<T> _handleResponse<T>(
    BuildContext? context,
    String dialogTitle,
    bool showDialog,
    http.Response response,
    T Function(Map<String, dynamic>)? parseModel, {
    VoidCallback? callback,
  }) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException("Response is not a valid JSON object");
      }

      debugPrint('Parsed JSON: $decoded');
      debugPrint('Status: ${decoded['status']}');
      debugPrint('Message: ${decoded['message']}');

      final bool isSuccess = decoded['status'] == true;
      debugPrint('Is success: $isSuccess');

      // Success case
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          isSuccess) {
        if (parseModel != null) {
          return ApiResponse.success(
            parseModel(decoded),
            rawData: decoded,
            message: decoded['message']?.toString(),
          );
        }
        return ApiResponse.success(
          null,
          rawData: decoded,
          message: decoded['message']?.toString(),
        );
      }

      // Error handling
      String errorMessage =
          decoded['message']?.toString() ?? 'Unknown error occurred';
      final resultJson = decoded['result'];

      if (resultJson is Map<String, dynamic>) {
        final errorField = resultJson['error'];
        if (errorField != null) {
          if (errorField is Map && errorField.isNotEmpty) {
            final firstError = errorField.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              errorMessage = firstError.first.toString();
            } else {
              errorMessage = firstError.toString();
            }
          } else if (errorField is String) {
            errorMessage = errorField;
          }
        }
      }

      debugPrint('Final error message: $errorMessage');

      // Hide loader before showing dialog
      if (showDialog && context != null) {
        try {
          hideLoader();
        } catch (e) {
          debugPrint('Error hiding loader before dialog: $e');
        }

        AppDialogs.showMessage(
          context: context,
          title: dialogTitle,
          message: errorMessage,
          positiveButton: DialogStrings.ok,
          callback: callback,
        );
      }

      return ApiResponse.error(errorMessage, rawData: decoded);
    } catch (e) {
      final errorMessage = 'Invalid response format: ${e.toString()}';

      if (showDialog && context != null) {
        try {
          hideLoader();
        } catch (e) {
          debugPrint('Error hiding loader before dialog: $e');
        }

        AppDialogs.showMessage(
          context: context,
          title: dialogTitle,
          message: errorMessage,
          positiveButton: DialogStrings.ok,
          callback: callback,
        );
      }

      return ApiResponse.error(errorMessage);
    }
  }
}

// import 'dart:convert';
// import 'package:datatransfer/core/api/api_headers.dart';
// import 'package:datatransfer/core/api/api_response.dart';
// import 'package:datatransfer/core/constants/app_strings.dart';
// import 'package:datatransfer/core/services/loading_service.dart';
// import 'package:datatransfer/shared/utils/app_dialogs.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// /// Professional API service class for handling HTTP requests
// class ApiClient {
//   static bool isLoading = false;

//   static Uri _buildUri(String url, [Map<String, dynamic>? queryParams]) {
//     return Uri.parse(url).replace(queryParameters: queryParams);
//   }

//   /// Performs GET request
//   static Future<ApiResponse<T>> get<T>({
//     required BuildContext context,
//     required String url,
//     required String dialogTitle,
//     bool showDialog = true,
//     Map<String, dynamic>? queryParams,
//     T Function(Map<String, dynamic>)? parseModel,
//     bool showLoading = true,
//     VoidCallback? callback,
//   }) async {
//     isLoading = true;
//     if (showLoading) {
//       try {
//         showLoader(context);
//       } catch (e) {
//         debugPrint('Error showing loader: $e');
//       }
//     }

//     try {
//       final response = await http.get(
//         _buildUri(url, queryParams),
//         headers: await ApiHeaders.defaultHeaders,
//       );

//       return _handleResponse(
//         context,
//         dialogTitle,
//         showDialog,
//         response,
//         parseModel,
//         callback: callback,
//       );
//     } catch (e) {
//       if (showDialog) {
//         AppDialogs.showMessage(
//           context: context,
//           title: dialogTitle,
//           message: e.toString(),
//           positiveButton: DialogStrings.ok,
//           callback: callback,
//         );
//       }
//       return ApiResponse.error(e.toString());
//     } finally {
//       isLoading = false;
//       if (showLoading) {
//         try {
//           await hideLoader();
//         } catch (e) {
//           debugPrint('Error hiding loader: $e');
//         }
//       }
//     }
//   }

//   /// Performs POST request with JSON body
//   static Future<ApiResponse<T>> post<T>({
//     required BuildContext context,
//     required String url,
//     required String dialogTitle,
//     bool showDialog = true,
//     Map<String, dynamic>? body,
//     T Function(Map<String, dynamic>)? parseModel,
//     bool showLoading = true,
//     VoidCallback? callback,
//   }) async {
//     isLoading = true;
//     if (showLoading) {
//       try {
//         showLoader(context);
//       } catch (e) {
//         debugPrint('Error showing loader: $e');
//       }
//     }

//     try {
//       debugPrint('POST body: $body');
//       final response = await http.post(
//         Uri.parse(url),
//         headers: await ApiHeaders.defaultHeaders,
//         body: jsonEncode(body ?? {}),
//       );

//       debugPrint('POST response: ${response.body}');
//       return _handleResponse(
//         context,
//         dialogTitle,
//         showDialog,
//         response,
//         parseModel,
//         callback: callback,
//       );
//     } catch (e) {
//       if (showDialog) {
//         AppDialogs.showMessage(
//           context: context,
//           title: dialogTitle,
//           message: e.toString(),
//           positiveButton: DialogStrings.ok,
//           callback: callback,
//         );
//       }
//       return ApiResponse.error(e.toString());
//     } finally {
//       isLoading = false;
//       if (showLoading) {
//         try {
//           await hideLoader();
//         } catch (e) {
//           debugPrint('Error hiding loader: $e');
//         }
//       }
//     }
//   }

//   /// Performs POST request with form data (no files)
//   static Future<ApiResponse<T>> postFormData<T>({
//     required BuildContext context,
//     required String url,
//     required String dialogTitle,
//     bool showDialog = true,
//     required Map<String, dynamic> fields,
//     T Function(Map<String, dynamic>)? parseModel,
//     bool showLoading = true,
//     VoidCallback? callback,
//   }) async {
//     isLoading = true;
//     if (showLoading) {
//       try {
//         showLoader(context);
//       } catch (e) {
//         debugPrint('Error showing loader: $e');
//       }
//     }

//     try {
//       final request = http.MultipartRequest('POST', Uri.parse(url));
//       request.headers.addAll(await ApiHeaders.multipartHeaders);

//       fields.forEach((key, value) {
//         request.fields[key] = value.toString();
//       });

//       final streamedResponse = await request.send();
//       final response = await http.Response.fromStream(streamedResponse);

//       debugPrint('Form data response: ${response.body}');
//       return _handleResponse(
//         context,
//         dialogTitle,
//         showDialog,
//         response,
//         parseModel,
//         callback: callback,
//       );
//     } catch (e) {
//       if (showDialog) {
//         AppDialogs.showMessage(
//           context: context,
//           title: dialogTitle,
//           message: e.toString(),
//           positiveButton: DialogStrings.ok,
//           callback: callback,
//         );
//       }
//       return ApiResponse.error(e.toString());
//     } finally {
//       isLoading = false;
//       if (showLoading) {
//         try {
//           await hideLoader();
//         } catch (e) {
//           debugPrint('Error hiding loader: $e');
//         }
//       }
//     }
//   }

//   /// Performs PUT request
//   static Future<ApiResponse<T>> put<T>({
//     required BuildContext context,
//     required String url,
//     required String dialogTitle,
//     bool showDialog = true,
//     Map<String, dynamic>? body,
//     T Function(Map<String, dynamic>)? parseModel,
//     bool showLoading = true,
//     VoidCallback? callback,
//   }) async {
//     isLoading = true;
//     if (showLoading) {
//       try {
//         showLoader(context);
//       } catch (e) {
//         debugPrint('Error showing loader: $e');
//       }
//     }

//     try {
//       final response = await http.put(
//         Uri.parse(url),
//         headers: await ApiHeaders.defaultHeaders,
//         body: jsonEncode(body ?? {}),
//       );

//       return _handleResponse(
//         context,
//         dialogTitle,
//         showDialog,
//         response,
//         parseModel,
//         callback: callback,
//       );
//     } catch (e) {
//       if (showDialog) {
//         AppDialogs.showMessage(
//           context: context,
//           title: dialogTitle,
//           message: e.toString(),
//           positiveButton: DialogStrings.ok,
//           callback: callback,
//         );
//       }
//       return ApiResponse.error(e.toString());
//     } finally {
//       isLoading = false;
//       if (showLoading) {
//         try {
//           await hideLoader();
//         } catch (e) {
//           debugPrint('Error hiding loader: $e');
//         }
//       }
//     }
//   }

//   /// Performs DELETE request
//   static Future<ApiResponse<T>> delete<T>({
//     required BuildContext context,
//     required String url,
//     required String dialogTitle,
//     bool showDialog = true,
//     Map<String, dynamic>? queryParams,
//     T Function(Map<String, dynamic>)? parseModel,
//     bool showLoading = true,
//     VoidCallback? callback,
//   }) async {
//     isLoading = true;
//     if (showLoading) {
//       try {
//         showLoader(context);
//       } catch (e) {
//         debugPrint('Error showing loader: $e');
//       }
//     }

//     try {
//       final response = await http.delete(
//         _buildUri(url, queryParams),
//         headers: await ApiHeaders.defaultHeaders,
//       );

//       return _handleResponse(
//         context,
//         dialogTitle,
//         showDialog,
//         response,
//         parseModel,
//         callback: callback,
//       );
//     } catch (e) {
//       if (showDialog) {
//         AppDialogs.showMessage(
//           context: context,
//           title: dialogTitle,
//           message: e.toString(),
//           positiveButton: DialogStrings.ok,
//           callback: callback,
//         );
//       }
//       return ApiResponse.error(e.toString());
//     } finally {
//       isLoading = false;
//       if (showLoading) {
//         try {
//           await hideLoader();
//         } catch (e) {
//           debugPrint('Error hiding loader: $e');
//         }
//       }
//     }
//   }

//   /// Performs multipart request with file uploads
//   static Future<ApiResponse<T>> multipart<T>({
//     required BuildContext context,
//     required String url,
//     required String dialogTitle,
//     bool showDialog = true,
//     required Map<String, String> fields,
//     required Map<String, String> files,
//     T Function(Map<String, dynamic>)? parseModel,
//     bool showLoading = true,
//     VoidCallback? callback,
//   }) async {
//     isLoading = true;
//     if (showLoading) {
//       try {
//         showLoader(context);
//       } catch (e) {
//         debugPrint('Error showing loader: $e');
//       }
//     }

//     try {
//       final request = http.MultipartRequest('POST', Uri.parse(url));
//       request.headers.addAll(await ApiHeaders.multipartHeaders);

//       fields.forEach((key, value) => request.fields[key] = value);

//       for (var entry in files.entries) {
//         request.files.add(
//           await http.MultipartFile.fromPath(entry.key, entry.value),
//         );
//       }

//       final streamedResponse = await request.send();
//       final response = await http.Response.fromStream(streamedResponse);

//       debugPrint('Multipart response: ${response.body}');
//       return _handleResponse(
//         context,
//         dialogTitle,
//         showDialog,
//         response,
//         parseModel,
//         callback: callback,
//       );
//     } catch (e) {
//       if (showDialog) {
//         AppDialogs.showMessage(
//           context: context,
//           title: dialogTitle,
//           message: e.toString(),
//           positiveButton: DialogStrings.ok,
//           callback: callback,
//         );
//       }
//       return ApiResponse.error(e.toString());
//     } finally {
//       isLoading = false;
//       if (showLoading) {
//         try {
//           await hideLoader();
//         } catch (e) {
//           debugPrint('Error hiding loader: $e');
//         }
//       }
//     }
//   }

//   /// Centralized response handler
//   static ApiResponse<T> _handleResponse<T>(
//     BuildContext? context,
//     String dialogTitle,
//     bool showDialog,
//     http.Response response,
//     T Function(Map<String, dynamic>)? parseModel, {
//     VoidCallback? callback,
//   }) {
//     try {
//       final decoded = jsonDecode(response.body);

//       // Handle JSON array responses (e.g., from https://jsonplaceholder.typicode.com/posts)
//       if (decoded is List) {
//         debugPrint('Response is a JSON array with ${decoded.length} items');

//         // For successful array responses (typically 200-299 status codes)
//         if (response.statusCode >= 200 && response.statusCode < 300) {
//           return ApiResponse.success(
//             null,
//             rawData: {'data': decoded}, // Wrap array in a data field
//             message: 'Success',
//           );
//         }

//         // Array response with error status code
//         return ApiResponse.error(
//           'Request failed with status ${response.statusCode}',
//           rawData: {'data': decoded},
//         );
//       }

//       // Handle JSON object responses
//       if (decoded is! Map<String, dynamic>) {
//         throw const FormatException(
//           "Response is not a valid JSON object or array",
//         );
//       }

//       debugPrint('Parsed JSON: $decoded');
//       debugPrint('Status: ${decoded['status']}');
//       debugPrint('Message: ${decoded['message']}');

//       final bool isSuccess = decoded['status'] == true;
//       debugPrint('Is success: $isSuccess');

//       // Success case
//       if (response.statusCode >= 200 &&
//           response.statusCode < 300 &&
//           isSuccess) {
//         if (parseModel != null && decoded is Map<String, dynamic>) {
//           return ApiResponse.success(
//             parseModel(decoded),
//             rawData: decoded,
//             message: decoded['message']?.toString(),
//           );
//         }
//         return ApiResponse.success(
//           null,
//           rawData: decoded,
//           message: decoded['message']?.toString(),
//         );
//       }

//       // Error handling
//       String errorMessage =
//           decoded['message']?.toString() ?? 'Unknown error occurred';
//       final resultJson = decoded['result'];

//       if (resultJson is Map<String, dynamic>) {
//         final errorField = resultJson['error'];
//         if (errorField != null) {
//           if (errorField is Map && errorField.isNotEmpty) {
//             final firstError = errorField.values.first;
//             if (firstError is List && firstError.isNotEmpty) {
//               errorMessage = firstError.first.toString();
//             } else {
//               errorMessage = firstError.toString();
//             }
//           } else if (errorField is String) {
//             errorMessage = errorField;
//           }
//         }
//       }

//       debugPrint('Final error message: $errorMessage');

//       // Hide loader before showing dialog
//       if (showDialog && context != null) {
//         try {
//           hideLoader();
//         } catch (e) {
//           debugPrint('Error hiding loader before dialog: $e');
//         }

//         AppDialogs.showMessage(
//           context: context,
//           title: dialogTitle,
//           message: errorMessage,
//           positiveButton: DialogStrings.ok,
//           callback: callback,
//         );
//       }

//       return ApiResponse.error(errorMessage, rawData: decoded);
//     } catch (e) {
//       final errorMessage = 'Invalid response format: ${e.toString()}';

//       if (showDialog && context != null) {
//         try {
//           hideLoader();
//         } catch (e) {
//           debugPrint('Error hiding loader before dialog: $e');
//         }

//         AppDialogs.showMessage(
//           context: context,
//           title: dialogTitle,
//           message: errorMessage,
//           positiveButton: DialogStrings.ok,
//           callback: callback,
//         );
//       }

//       return ApiResponse.error(errorMessage);
//     }
//   }
// }
