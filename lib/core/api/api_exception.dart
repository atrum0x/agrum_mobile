import 'package:dio/dio.dart';
import '../i18n/app_strings.dart';

/// An error from agrum_be, or no connection. [message] is ready to show: the server's
/// ApiErrorResponse already holds the FSD wording.
class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.isNetwork = false});

  final String message;
  final int? status;

  /// No connection, or the server could not be reached.
  final bool isNetwork;

  bool get isUnauthorized => status == 401;

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return ApiException(tr.cannotReachServer, isNetwork: true);
        default:
          break;
      }
      final response = error.response;
      if (response != null) {
        final data = response.data;
        final serverMessage = data is Map ? data['message'] as String? : null;
        return ApiException(
          serverMessage ?? _fallback(response.statusCode),
          status: response.statusCode,
        );
      }
    }
    return ApiException(error.toString());
  }

  static String _fallback(int? status) => switch (status) {
        401 => tr.sessionExpired,
        403 => tr.noPermissionGeneric,
        429 => tr.tooManyRequests,
        _ => tr.somethingWentWrong,
      };

  @override
  String toString() => message;
}
