import 'package:url_launcher/url_launcher.dart';

/// Opens the backend-provided payment URL in an external browser/app.
///
/// Only `http` and `https` URLs with a host are launchable. Loopback, LAN,
/// and emulator addresses are intentionally NOT rejected here: whether a
/// development mock URL is reachable depends on where the app runs
/// (host browser vs emulator vs physical device), so reachability failures
/// are reported with actionable guidance instead of being blocked upfront.
///
/// Rejected outright: missing/empty URLs, unparsable values, and non-HTTP(S)
/// schemes such as `javascript:`, `file:`, or arbitrary custom schemes.
bool isLaunchablePaymentUrl(String? url) {
  if (url == null) return false;
  final raw = url.trim();
  if (raw.isEmpty) return false;
  final uri = Uri.tryParse(raw);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;
  return true;
}

/// Signature for opening a validated payment [Uri].
///
/// Separated from `launchUrl` so widget tests can inject a fake instead of
/// opening a real browser.
typedef LaunchPaymentUri = Future<bool> Function(Uri uri);

/// Default launcher: opens the URL in an external browser/application.
///
/// Returns `true` when the platform accepted the request. Dispatch does not
/// imply payment success — callers must re-read payment status afterwards.
Future<bool> defaultLaunchPaymentUri(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Human-readable hint shown when a development payment URL cannot be opened.
///
/// The mock/simulator URL is served by the developer's environment, so the
/// fix is about reachability, not about the payment itself.
String unreachablePaymentUrlHint(String url) {
  final host = Uri.tryParse(url.trim())?.host ?? '';
  final loopback = host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host.startsWith('10.') ||
      host.startsWith('192.168.') ||
      host.startsWith('172.');
  if (loopback) {
    return 'The payment page ($url) could not be opened. '
        'Development payment URLs must be reachable from this device: '
        'use your machine\'s LAN address for a physical device '
        '(or 10.0.2.2 from an Android emulator) and keep the backend running.';
  }
  return 'The payment page could not be opened ($url). '
      'Check the address and try again.';
}
