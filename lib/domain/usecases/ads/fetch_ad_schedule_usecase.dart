import '../../entities/ad_schedule_item.dart';
import '../../repositories/ad_repository.dart';

class FetchAdScheduleUsecase {
  const FetchAdScheduleUsecase(this._repository);

  final AdRepository _repository;

  Future<List<AdScheduleItem>> call() {
    return _repository.fetchSchedule();
  }
}
