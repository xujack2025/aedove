import 'package:aedove/domain/entities/ad_schedule_item.dart';
import 'package:aedove/domain/repositories/ad_repository.dart';
import 'package:aedove/domain/usecases/ads/fetch_ad_schedule_usecase.dart';
import 'package:aedove/domain/usecases/ads/rotate_ad_item_usecase.dart';
import 'package:aedove/presentation/bloc/ads/ads_bloc.dart';
import 'package:aedove/presentation/bloc/ads/ads_event.dart';
import 'package:aedove/presentation/bloc/ads/ads_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdRepository implements AdRepository {
  _FakeAdRepository(this.items);

  final List<AdScheduleItem> items;

  @override
  Future<List<AdScheduleItem>> fetchSchedule() async => items;
}

void main() {
  group('AdsBloc', () {
    test('loads schedule on start and emits active ad state', () async {
      final repo = _FakeAdRepository(const [
        AdScheduleItem(
          link: 'https://example.com/a',
          showSeconds: 10,
          hideSeconds: 5,
        ),
      ]);

      final bloc = AdsBloc(
        fetchAdScheduleUsecase: FetchAdScheduleUsecase(repo),
        rotateAdItemUsecase: const RotateAdItemUsecase(),
      );

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          const AdsState(
            currentLink: 'https://example.com/a',
            isVisible: true,
            isActive: true,
          ),
        ]),
      );

      bloc.add(const AdsStarted());
      await expectation;
      await bloc.close();
    });

    test('rotates to next ad after hide cycle event', () async {
      final repo = _FakeAdRepository(const [
        AdScheduleItem(
          link: 'https://example.com/a',
          showSeconds: 10,
          hideSeconds: 5,
        ),
        AdScheduleItem(
          link: 'https://example.com/b',
          showSeconds: 10,
          hideSeconds: 5,
        ),
      ]);

      final bloc = AdsBloc(
        fetchAdScheduleUsecase: FetchAdScheduleUsecase(repo),
        rotateAdItemUsecase: const RotateAdItemUsecase(),
      );

      bloc.add(const AdsStarted());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          const AdsState(
            currentLink: 'https://example.com/b',
            isVisible: true,
            isActive: true,
          ),
        ]),
      );

      bloc.add(const AdsHideCycleElapsed());
      await expectation;
      await bloc.close();
    });
  });
}
