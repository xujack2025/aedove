import 'package:aedove/domain/repositories/app_init_repository.dart';
import 'package:aedove/domain/usecases/app_init/initialize_app_usecase.dart';
import 'package:aedove/presentation/bloc/app_init/app_init_bloc.dart';
import 'package:aedove/presentation/bloc/app_init/app_init_event.dart';
import 'package:aedove/presentation/bloc/app_init/app_init_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAppInitRepository implements AppInitRepository {
  _FakeAppInitRepository({this.shouldThrow = false});

  final bool shouldThrow;

  @override
  Future<void> initialize() async {
    if (shouldThrow) {
      throw Exception('init failed');
    }
  }
}

void main() {
  group('AppInitBloc', () {
    test('emits loading then success when initialization succeeds', () async {
      final bloc = AppInitBloc(
        initializeAppUsecase: InitializeAppUsecase(_FakeAppInitRepository()),
      );

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          const AppInitState(status: AppInitStatus.loading),
          const AppInitState(status: AppInitStatus.success),
        ]),
      );

      bloc.add(const AppInitStarted());
      await expectation;
      await bloc.close();
    });

    test('emits loading then failure when initialization fails', () async {
      final bloc = AppInitBloc(
        initializeAppUsecase: InitializeAppUsecase(
          _FakeAppInitRepository(shouldThrow: true),
        ),
      );

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          const AppInitState(status: AppInitStatus.loading),
          isA<AppInitState>().having(
            (state) => state.status,
            'status',
            AppInitStatus.failure,
          ),
        ]),
      );

      bloc.add(const AppInitStarted());
      await expectation;
      await bloc.close();
    });
  });
}
