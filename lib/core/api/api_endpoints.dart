/// Centralized API endpoints management
class ApiEndpoints {
  // -------- Base URL --------
  static const String baseUrl = 'https://jsonplaceholder.typicode.com';

  static String get currentBaseUrl => baseUrl;

  // -------- GET --------
  /// GET: Fetch all posts
  static String get getPosts => '$currentBaseUrl/posts';

  // -------- ADD --------
  /// POST: Create todo
  static String get addTodo => '$currentBaseUrl/todos';

  // -------- UPDATE --------
  /// PUT: Update todo
  static String updateTodo(int id) => '$currentBaseUrl/todos/$id';

  // -------- DELETE --------
  /// DELETE: Delete todo
  static String deleteTodo(int id) => '$currentBaseUrl/todos/$id';
}
