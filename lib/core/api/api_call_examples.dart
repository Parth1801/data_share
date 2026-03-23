// import 'package:flutter/material.dart';
// import 'package:todo_app_riverpod/core/api/api_client.dart';
// import 'package:todo_app_riverpod/core/api/api_endpoints.dart';
// import 'package:todo_app_riverpod/core/api/api_response.dart';
// import 'package:todo_app_riverpod/view/auth/data/models/user_model.dart';

// /// Example file showing how to call APIs using ApiClient
// /// 
// /// This file contains commented examples for different types of API calls.
// /// Uncomment and modify as needed when your APIs are ready.

// class ApiCallExamples {
  
//   // ========================================
//   // Example 1: Simple GET Request
//   // ========================================
  
//   /*
//   Future<void> fetchUserProfile(BuildContext context) async {
//     final response = await ApiClient.get(
//       context: context,
//       url: ApiEndpoints.getProfile,
//       dialogTitle: 'Fetch Profile',
//       showLoading: true,
//       showDialog: true,
//     );

//     if (response.isSuccess) {
//       // Access raw data
//       final userData = response.rawData;
//       print('User data: $userData');
      
//       // Access message
//       print('Message: ${response.message}');
//     } else {
//       // Handle error
//       print('Error: ${response.error}');
//     }
//   }
//   */

//   // ========================================
//   // Example 2: GET with Query Parameters
//   // ========================================
  
//   /*
//   Future<void> searchUsers(BuildContext context, String query) async {
//     final response = await ApiClient.get(
//       context: context,
//       url: ApiEndpoints.searchUsers,
//       queryParams: {
//         'q': query,
//         'limit': 10,
//         'status': 'active',
//       },
//       dialogTitle: 'Search Users',
//     );

//     if (response.isSuccess) {
//       final users = response.rawData?['users'] as List?;
//       print('Found ${users?.length ?? 0} users');
//     }
//   }
//   */

//   // ========================================
//   // Example 3: GET with Model Parsing
//   // ========================================
  
//   /*
//   Future<void> getUserWithModel(BuildContext context, String userId) async {
//     final response = await ApiClient.get<AppUser>(
//       context: context,
//       url: ApiEndpoints.userById(userId),
//       parseModel: (json) => AppUser.fromJson(json['data']),
//       dialogTitle: 'Get User',
//     );

//     if (response.isSuccess && response.data != null) {
//       final user = response.data!;
//       print('User name: ${user.name}');
//       print('User email: ${user.email}');
//     }
//   }
//   */

//   // ========================================
//   // Example 4: POST Request with JSON Body
//   // ========================================
  
//   /*
//   Future<void> createUser(BuildContext context) async {
//     final response = await ApiClient.post(
//       context: context,
//       url: ApiEndpoints.createUser,
//       body: {
//         'name': 'John Doe',
//         'email': 'john@example.com',
//         'password': 'secure123',
//       },
//       dialogTitle: 'Create User',
//       showLoading: true,
//     );

//     if (response.isSuccess) {
//       print('User created successfully!');
//       print('Response: ${response.rawData}');
//     }
//   }
//   */

//   // ========================================
//   // Example 5: POST with Model Parsing
//   // ========================================
  
//   /*
//   Future<void> loginUser(BuildContext context, String email, String password) async {
//     final response = await ApiClient.post<AppUser>(
//       context: context,
//       url: ApiEndpoints.login,
//       body: {
//         'email': email,
//         'password': password,
//       },
//       parseModel: (json) => AppUser.fromJson(json['user']),
//       dialogTitle: 'Login',
//     );

//     if (response.isSuccess && response.data != null) {
//       final user = response.data!;
//       // Save user data, navigate to home, etc.
//       print('Logged in as: ${user.name}');
//     }
//   }
//   */

//   // ========================================
//   // Example 6: PUT Request to Update Data
//   // ========================================
  
//   /*
//   Future<void> updateUserProfile(
//     BuildContext context,
//     String userId,
//     String name,
//     String email,
//   ) async {
//     final response = await ApiClient.put(
//       context: context,
//       url: ApiEndpoints.updateUser(userId),
//       body: {
//         'name': name,
//         'email': email,
//       },
//       dialogTitle: 'Update Profile',
//     );

//     if (response.isSuccess) {
//       print('Profile updated successfully!');
//     }
//   }
//   */

//   // ========================================
//   // Example 7: DELETE Request
//   // ========================================
  
//   /*
//   Future<void> deleteUser(BuildContext context, String userId) async {
//     final response = await ApiClient.delete(
//       context: context,
//       url: ApiEndpoints.deleteUser(userId),
//       dialogTitle: 'Delete User',
//     );

//     if (response.isSuccess) {
//       print('User deleted successfully');
//     }
//   }
//   */

//   // ========================================
//   // Example 8: Multipart File Upload
//   // ========================================
  
//   /*
//   Future<void> uploadProfileImage(
//     BuildContext context,
//     String userId,
//     String imagePath,
//   ) async {
//     final response = await ApiClient.multipart(
//       context: context,
//       url: ApiEndpoints.uploadImage,
//       fields: {
//         'user_id': userId,
//         'description': 'Profile picture',
//       },
//       files: {
//         'image': imagePath,  // Path to image file
//       },
//       dialogTitle: 'Upload Image',
//     );

//     if (response.isSuccess) {
//       print('Image uploaded successfully!');
//       final imageUrl = response.rawData?['image_url'];
//       print('Image URL: $imageUrl');
//     }
//   }
//   */

//   // ========================================
//   // Example 9: Form Data (No Files)
//   // ========================================
  
//   /*
//   Future<void> submitFormData(BuildContext context) async {
//     final response = await ApiClient.postFormData(
//       context: context,
//       url: ApiEndpoints.submitForm,
//       fields: {
//         'name': 'John',
//         'age': 25,
//         'city': 'New York',
//       },
//       dialogTitle: 'Submit Form',
//     );

//     if (response.isSuccess) {
//       print('Form submitted!');
//     }
//   }
//   */

//   // ========================================
//   // Example 10: Silent API Call (No Loading/Dialog)
//   // ========================================
  
//   /*
//   Future<void> silentApiCall(BuildContext context) async {
//     final response = await ApiClient.get(
//       context: context,
//       url: ApiEndpoints.getData,
//       dialogTitle: 'Fetch Data',
//       showLoading: false,  // No loading overlay
//       showDialog: false,   // No error dialogs
//     );

//     if (response.isSuccess) {
//       // Handle success silently
//       print('Data fetched silently');
//     } else {
//       // Handle error manually
//       print('Error: ${response.error}');
//     }
//   }
//   */

//   // ========================================
//   // Example 11: With Callback After Dialog
//   // ========================================
  
//   /*
//   Future<void> apiWithCallback(BuildContext context) async {
//     final response = await ApiClient.post(
//       context: context,
//       url: ApiEndpoints.createItem,
//       body: {'name': 'New Item'},
//       dialogTitle: 'Create Item',
//       callback: () {
//         // This runs after dialog is dismissed
//         print('Dialog closed, navigating...');
//         Navigator.pop(context);
//       },
//     );

//     if (response.isSuccess) {
//       print('Item created!');
//     }
//   }
//   */

//   // ========================================
//   // Example 12: Using withParams Helper
//   // ========================================
  
//   /*
//   Future<void> getFilteredData(BuildContext context) async {
//     final url = ApiEndpoints.withParams(
//       ApiEndpoints.getItems,
//       {
//         'category': 'electronics',
//         'min_price': 100,
//         'max_price': 1000,
//         'sort': 'price_asc',
//       },
//     );

//     final response = await ApiClient.get(
//       context: context,
//       url: url,
//       dialogTitle: 'Get Items',
//     );

//     if (response.isSuccess) {
//       print('Filtered data: ${response.rawData}');
//     }
//   }
//   */

//   // ========================================
//   // Example 13: Handling Token Management
//   // ========================================
  
//   /*
//   // After login, save token
//   Future<void> saveTokenAfterLogin(String token) async {
//     await SharedPrefsService().setUserToken(token);
//     // Now all subsequent API calls will include this token automatically!
//   }

//   // On logout, clear token
//   Future<void> clearTokenOnLogout() async {
//     await SharedPrefsService().clearUserToken();
//   }
//   */

//   // ========================================
//   // Example 14: Complete Login Flow
//   // ========================================
  
//   /*
//   Future<void> completeLoginFlow(
//     BuildContext context,
//     String email,
//     String password,
//   ) async {
//     final response = await ApiClient.post<AppUser>(
//       context: context,
//       url: ApiEndpoints.login,
//       body: {'email': email, 'password': password},
//       parseModel: (json) {
//         // Save token from response
//         final token = json['token'] as String;
//         SharedPrefsService().setUserToken(token);
        
//         // Parse user model
//         return AppUser.fromJson(json['user']);
//       },
//       dialogTitle: 'Login',
//       callback: () {
//         // Navigate to home after success dialog
//         Navigator.pushReplacementNamed(context, '/home');
//       },
//     );

//     if (response.isSuccess && response.data != null) {
//       print('Login successful for: ${response.data!.name}');
//     }
//   }
//   */
// }
