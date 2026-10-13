import 'package:payment_simulator/core/error/failure.dart';

import '../entities/dashboard_overview.dart';

/// Result of a dashboard overview use case.
///
/// A sealed type so the presentation layer can exhaustively handle success
/// and failure without catching exceptions.
sealed class DashboardOverviewResult<T> {
  const DashboardOverviewResult();
}

/// The use case succeeded.
final class DashboardOverviewSuccess<T> extends DashboardOverviewResult<T> {
  const DashboardOverviewSuccess(this.value);

  final T value;
}

/// The use case failed with a user-safe, domain-level failure.
final class DashboardOverviewError<T> extends DashboardOverviewResult<T> {
  const DashboardOverviewError(this.failure);

  final Failure failure;
}

/// Contract for dashboard overview data operations.
///
/// All methods return a [DashboardOverviewResult] — raw HTTP responses,
/// status codes, and exceptions never escape this boundary.
abstract class DashboardOverviewRepository {
  /// Returns the merchant-scoped dashboard overview for the period
  /// `[from, to)` (RFC3339 / YYYY-MM-DD, interpreted as UTC).
  Future<DashboardOverviewResult<DashboardOverview>> getOverview({
    required DateTime from,
    required DateTime to,
  });
}
