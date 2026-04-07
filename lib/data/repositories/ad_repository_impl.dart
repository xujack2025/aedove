import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../constant.dart';
import '../../domain/entities/ad_schedule_item.dart';
import '../../domain/repositories/ad_repository.dart';

class AdRepositoryImpl implements AdRepository {
  const AdRepositoryImpl();

  @override
  Future<List<AdScheduleItem>> fetchSchedule() async {
    final response = await http.get(Uri.parse(Constant.AD_API));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch ad schedule: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final advertisements = (decoded['advertisements'] as List<dynamic>? ?? []);

    return advertisements
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => AdScheduleItem(
            link: (item['link'] ?? Constant.AD_URL).toString(),
            showSeconds: _toPositiveInt(item['show'], fallback: 10),
            hideSeconds: _toPositiveInt(item['hide'], fallback: 5),
          ),
        )
        .toList();
  }

  int _toPositiveInt(dynamic value, {required int fallback}) {
    final parsed = value is int
        ? value
        : int.tryParse(value?.toString() ?? '') ?? fallback;
    if (parsed <= 0) {
      return fallback;
    }
    return parsed;
  }
}
