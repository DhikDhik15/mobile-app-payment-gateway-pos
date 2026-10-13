import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/home/domain/entities/backend_connection_status.dart';
import 'package:payment_simulator/features/home/domain/usecases/check_backend_connection.dart';

/// Cubit for the development-only backend connectivity check shown on the
/// home dashboard.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required this.checkConnection}) : super(const HomeState());

  final CheckBackendConnectionUseCase checkConnection;

  /// Runs the backend connectivity check and emits the resulting status.
  Future<void> checkBackendConnection() async {
    emit(state.copyWith(connection: const BackendChecking()));
    final status = await checkConnection(const NoParams());
    emit(state.copyWith(connection: status));
  }
}

/// State for [HomeCubit].
class HomeState {
  const HomeState({this.connection = const BackendNotChecked()});

  final BackendConnectionStatus connection;

  HomeState copyWith({BackendConnectionStatus? connection}) {
    return HomeState(connection: connection ?? this.connection);
  }
}
