import 'package:payment_simulator/core/usecases/usecase.dart';

import '../entities/dashboard_overview.dart';
import '../repositories/dashboard_overview_repository.dart';

/// Parameters for [GetDashboardOverviewUseCase].
class GetDashboardOverviewParams {
  const GetDashboardOverviewParams({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}

/// Use case that retrieves the merchant dashboard overview for a period.
class GetDashboardOverviewUseCase
    implements
        UseCase<DashboardOverviewResult<DashboardOverview>,
            GetDashboardOverviewParams> {
  const GetDashboardOverviewUseCase(this._repository);

  final DashboardOverviewRepository _repository;

  @override
  Future<DashboardOverviewResult<DashboardOverview>> call(
    GetDashboardOverviewParams params,
  ) =>
      _repository.getOverview(from: params.from, to: params.to);
}
