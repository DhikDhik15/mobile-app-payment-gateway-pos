import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/home/domain/entities/dashboard_overview.dart';
import 'package:payment_simulator/features/home/domain/repositories/dashboard_overview_repository.dart';
import 'package:payment_simulator/features/home/domain/usecases/get_dashboard_overview.dart';

/// Cubit that backs the merchant POS home dashboard.
///
/// Loads today's sales summary and recent transactions from the existing
/// `GET /api/v1/dashboard/overview` endpoint (UTC calendar day).
class PosHomeCubit extends Cubit<PosHomeState> {
  PosHomeCubit({required this.getOverview}) : super(const PosHomeInitial());

  final GetDashboardOverviewUseCase getOverview;

  /// Loads today's overview (UTC calendar day).
  ///
  /// Concurrent calls collapse into one request: a refresh issued while a
  /// load is already in flight is ignored, so pull-to-refresh cannot issue
  /// duplicate backend requests.
  Future<void> loadToday() async {
    if (state is PosHomeLoading) return;
    emit(const PosHomeLoading());
    final now = DateTime.now().toUtc();
    final from = DateTime.utc(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 1));
    final result = await getOverview(
      GetDashboardOverviewParams(from: from, to: to),
    );
    switch (result) {
      case DashboardOverviewSuccess(value: final overview):
        emit(PosHomeLoaded(overview));
      case DashboardOverviewError(failure: final failure):
        emit(PosHomeFailure(failure.message));
    }
  }
}

/// Sealed POS home state hierarchy.
sealed class PosHomeState {
  const PosHomeState();
}

final class PosHomeInitial extends PosHomeState {
  const PosHomeInitial();
}

final class PosHomeLoading extends PosHomeState {
  const PosHomeLoading();
}

final class PosHomeLoaded extends PosHomeState {
  const PosHomeLoaded(this.overview);

  final DashboardOverview overview;
}

final class PosHomeFailure extends PosHomeState {
  const PosHomeFailure(this.message);

  final String message;
}
