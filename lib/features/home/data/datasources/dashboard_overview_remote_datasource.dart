import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/api_endpoints.dart';
import 'package:payment_simulator/core/network/network_response.dart';
import 'package:payment_simulator/features/home/data/models/dashboard_overview_model.dart';

/// Contract for remote dashboard overview data sources.
abstract class DashboardOverviewRemoteDataSource {
  const DashboardOverviewRemoteDataSource();

  /// `GET /api/v1/dashboard/overview?from=<from>&to=<to>`
  Future<DashboardOverviewModel> getOverview({
    required DateTime from,
    required DateTime to,
  });
}

/// HTTP implementation of [DashboardOverviewRemoteDataSource].
class DashboardOverviewRemoteDataSourceImpl
    extends DashboardOverviewRemoteDataSource {
  const DashboardOverviewRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DashboardOverviewModel> getOverview({
    required DateTime from,
    required DateTime to,
  }) async {
    final path = '${ApiEndpoints.dashboardOverview}'
        '?from=${_formatDay(from)}&to=${_formatDay(to)}';
    final response = await _apiClient.get(path);
    return _parse(response);
  }

  DashboardOverviewModel _parse(NetworkResponse response) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const InvalidResponseException(
        'Expected a dashboard overview object but received an unexpected payload',
      );
    }
    return DashboardOverviewModel.fromJson(data);
  }

  /// Formats as `YYYY-MM-DD` (interpreted by the backend as UTC midnight).
  String _formatDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
