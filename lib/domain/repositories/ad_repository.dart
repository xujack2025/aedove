import '../entities/ad_schedule_item.dart';

abstract class AdRepository {
  Future<List<AdScheduleItem>> fetchSchedule();
}
