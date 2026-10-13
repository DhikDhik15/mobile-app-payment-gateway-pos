import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/home/data/datasources/dashboard_overview_remote_datasource.dart';
import 'package:payment_simulator/features/home/domain/entities/dashboard_overview.dart';
import 'package:payment_simulator/features/home/domain/repositories/dashboard_overview_repository.dart';

/// Data-layer implementation of [DashboardOverviewRepository].
class DashboardOverviewRepositoryImpl implements DashboardOverviewRepository {
  const DashboardOverviewRepositoryImpl(this._remote);

  final DashboardOverviewRemoteDataSource _remote;

  @override
  Future<DashboardOverviewResult<DashboardOverview>> getOverview({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final overview = await _remote.getOverview(from: from, to: to);
      return DashboardOverviewSuccess(overview);
    } on AppException catch (error) {
      return DashboardOverviewError(_mapError(error));
    }
  }

  /// Maps a network-layer [AppException] to a domain [Failure] with a
  /// user-safe message.
  Failure _mapError(AppException error) {
    return switch (error) {
      NetworkTimeoutException() => const TimeoutFailure(),
      ConnectionNetworkException() => const ConnectionFailure(),
      ApiException() => ApiFailure(error.statusCode, error.message),
      InvalidResponseException() => const InvalidResponseFailure(),
      _ => const ServerFailure(),
    };
  }
}
