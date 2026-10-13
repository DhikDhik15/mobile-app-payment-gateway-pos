/// Network-level configuration constants.
///
/// These values are shared across all features and provide the foundation
/// for HTTP client configuration (timeouts, default headers, etc.).
class NetworkConfig {
  const NetworkConfig._();

  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
