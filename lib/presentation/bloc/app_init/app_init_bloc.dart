import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/app_init/initialize_app_usecase.dart';
import 'app_init_event.dart';
import 'app_init_state.dart';

class AppInitBloc extends Bloc<AppInitEvent, AppInitState> {
  AppInitBloc({required InitializeAppUsecase initializeAppUsecase})
    : _initializeAppUsecase = initializeAppUsecase,
      super(const AppInitState()) {
    on<AppInitStarted>(_onStarted);
  }

  final InitializeAppUsecase _initializeAppUsecase;

  Future<void> _onStarted(
    AppInitStarted event,
    Emitter<AppInitState> emit,
  ) async {
    emit(state.copyWith(status: AppInitStatus.loading, clearError: true));
    try {
      await _initializeAppUsecase();
      emit(state.copyWith(status: AppInitStatus.success, clearError: true));
    } catch (e) {
      emit(
        state.copyWith(
          status: AppInitStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
