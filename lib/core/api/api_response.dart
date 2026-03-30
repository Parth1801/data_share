/// Generic API response wrapper that encapsulates success and error states
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;
  final Map<String, dynamic>? rawData;
  final String? message;

  ApiResponse.success(this.data, {this.rawData, this.message})
    : isSuccess = true,
      error = null;

  ApiResponse.error(this.error, {this.rawData, this.message})
    : isSuccess = false,
      data = null;
}
