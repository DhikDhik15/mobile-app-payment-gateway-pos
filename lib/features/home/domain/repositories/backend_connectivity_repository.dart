import 'package:payment_simulator/features/home/domain/entities/backend_connection_status.dart';

/// Contract for checking backend connectivity.
///
/// Lives in the domain layer so the use case (and therefore the presentation
/// layer) depends only on this abstraction — never on HTTP details.
abstract class BackendConnectivityRepository {
  /// Performs a connectivity check against the configured backend and
  /// returns a [BackendConnectionStatus] describing the outcome.
  Future<BackendConnectionStatus> check();
}
