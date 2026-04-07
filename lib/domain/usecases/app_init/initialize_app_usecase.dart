import '../../repositories/app_init_repository.dart';

class InitializeAppUsecase {
  const InitializeAppUsecase(this._repository);

  final AppInitRepository _repository;

  Future<void> call() {
    return _repository.initialize();
  }
}
