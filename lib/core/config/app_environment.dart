import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized application environment configuration.
///
/// The backend base URL is loaded at startup from the bundled `.env` asset
/// (via `flutter_dotenv`). No hardcoded LAN/DHCP-dependent IP address lives
/// in the Dart source — the developer only edits `.env`:
///
///   API_BASE_URL=http://192.168.x.x:8081
///
/// This replaces the former `--dart-define=API_BASE_URL` mechanism. The
/// single source of truth for the value is `.env`.
class AppEnvironment {
  const AppEnvironment._();

  /// The effective backend base URL, loaded from `.env` at startup.
  ///
  /// Returns an empty string when the key is missing or blank — callers
  /// (startup validation) must reject that case explicitly.
  static String get apiBaseUrl => dotenv.env['API_BASE_URL']?.trim() ?? '';

  /// Fails fast when API_BASE_URL is missing or empty. Called once during
  /// application startup before any network client is created.
  static void validate() {
    if (apiBaseUrl.isEmpty) {
      throw StateError('API_BASE_URL is not configured in .env');
    }
  }
}
