import 'dart:async';
import 'dart:io';

/// User-friendly error info with a short code for debugging.
class AppError {
  final String message;
  final String code;
  final String? debugDetail;

  const AppError({
    required this.message,
    required this.code,
    this.debugDetail,
  });

  /// User-visible string: friendly message + code
  String get displayMessage => message;

  /// Short code shown in small text for support/debugging
  String get displayCode => 'Error: $code';
}

/// Converts raw exceptions into user-friendly error messages.
class ErrorUtils {
  static AppError fromException(Object error) {
    final raw = error.toString();

    // Timeout
    if (error is TimeoutException) {
      return AppError(
        message: 'Server took too long to respond',
        code: 'E_TIMEOUT',
        debugDetail: raw,
      );
    }

    // Socket / connection errors
    if (error is SocketException) {
      if (raw.contains('errno = 103') || raw.contains('Connection abort')) {
        return AppError(
          message: 'Connection blocked by network',
          code: 'E_CONN_ABORT',
          debugDetail: raw,
        );
      }
      if (raw.contains('Connection refused')) {
        return AppError(
          message: 'Server is not reachable',
          code: 'E_CONN_REFUSED',
          debugDetail: raw,
        );
      }
      if (raw.contains('No route to host') || raw.contains('Network is unreachable')) {
        return AppError(
          message: 'No internet connection',
          code: 'E_NO_NETWORK',
          debugDetail: raw,
        );
      }
      if (raw.contains('Failed host lookup') || raw.contains('getaddrinfo')) {
        return AppError(
          message: 'Could not find the server',
          code: 'E_DNS_FAIL',
          debugDetail: raw,
        );
      }
      return AppError(
        message: 'Unable to connect to server',
        code: 'E_SOCKET',
        debugDetail: raw,
      );
    }

    // HTTP client exceptions (wraps SocketException)
    if (raw.contains('ClientException') || raw.contains('SocketException')) {
      if (raw.contains('errno = 103') || raw.contains('connection abort')) {
        return AppError(
          message: 'Connection blocked by network',
          code: 'E_CONN_ABORT',
          debugDetail: raw,
        );
      }
      if (raw.contains('Connection refused')) {
        return AppError(
          message: 'Server is not reachable',
          code: 'E_CONN_REFUSED',
          debugDetail: raw,
        );
      }
      if (raw.contains('Failed host lookup')) {
        return AppError(
          message: 'Could not find the server',
          code: 'E_DNS_FAIL',
          debugDetail: raw,
        );
      }
      return AppError(
        message: 'Unable to connect to server',
        code: 'E_CONNECTION',
        debugDetail: raw,
      );
    }

    // TLS/Certificate errors
    if (raw.contains('HandshakeException') || raw.contains('CERTIFICATE')) {
      return AppError(
        message: 'Secure connection failed',
        code: 'E_TLS',
        debugDetail: raw,
      );
    }

    // API errors (our own ApiException)
    if (raw.contains('ApiException')) {
      if (raw.contains('500') || raw.contains('502') || raw.contains('503')) {
        return AppError(
          message: 'Server is temporarily unavailable',
          code: 'E_SERVER',
          debugDetail: raw,
        );
      }
      if (raw.contains('404')) {
        return AppError(
          message: 'Content not found',
          code: 'E_NOT_FOUND',
          debugDetail: raw,
        );
      }
      return AppError(
        message: 'Server returned an error',
        code: 'E_API',
        debugDetail: raw,
      );
    }

    // Generic fallback
    return AppError(
      message: 'Something went wrong',
      code: 'E_UNKNOWN',
      debugDetail: raw,
    );
  }
}
