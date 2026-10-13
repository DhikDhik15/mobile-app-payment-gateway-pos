import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/home/domain/entities/dashboard_overview.dart';
import 'package:payment_simulator/features/home/domain/repositories/dashboard_overview_repository.dart';
import 'package:payment_simulator/features/home/domain/usecases/get_dashboard_overview.dart';
import 'package:payment_simulator/features/home/presentation/bloc/pos_home_cubit.dart';

class _FakeRepo implements DashboardOverviewRepository {
  _FakeRepo(this.result);

  final DashboardOverviewResult<DashboardOverview> result;

  @override
  Future<DashboardOverviewResult<DashboardOverview>> getOverview({
    required DateTime from,
    required DateTime to,
  }) async {
    return result;
  }
}

const _overview = DashboardOverview(
  revenueAmount: 75000,
  currency: 'IDR',
  paidCount: 1,
  pendingCount: 0,
  failedCount: 0,
  recentTransactions: [],
);

void main() {
  test('emits loaded on success', () async {
    final cubit = PosHomeCubit(
      getOverview: GetDashboardOverviewUseCase(
        _FakeRepo(const DashboardOverviewSuccess(_overview)),
      ),
    );
    await cubit.loadToday();
    final state = cubit.state;
    expect(state, isA<PosHomeLoaded>());
    expect((state as PosHomeLoaded).overview.revenueAmount, 75000);
    await cubit.close();
  });

  test('emits failure on error', () async {
    final cubit = PosHomeCubit(
      getOverview: GetDashboardOverviewUseCase(
        _FakeRepo(const DashboardOverviewError(ConnectionFailure())),
      ),
    );
    await cubit.loadToday();
    expect(cubit.state, isA<PosHomeFailure>());
    await cubit.close();
  });
}
