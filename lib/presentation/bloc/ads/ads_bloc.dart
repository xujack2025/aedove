import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/ad_schedule_item.dart';
import '../../../domain/usecases/ads/fetch_ad_schedule_usecase.dart';
import '../../../domain/usecases/ads/rotate_ad_item_usecase.dart';
import 'ads_event.dart';
import 'ads_state.dart';

class AdsBloc extends Bloc<AdsEvent, AdsState> {
  AdsBloc({
    required FetchAdScheduleUsecase fetchAdScheduleUsecase,
    required RotateAdItemUsecase rotateAdItemUsecase,
  }) : _fetchAdScheduleUsecase = fetchAdScheduleUsecase,
       _rotateAdItemUsecase = rotateAdItemUsecase,
       super(const AdsState()) {
    on<AdsStarted>(_onStarted);
    on<AdsRefreshRequested>(_onRefreshRequested);
    on<AdsToggled>(_onToggled);
    on<AdsShowCycleElapsed>(_onShowCycleElapsed);
    on<AdsHideCycleElapsed>(_onHideCycleElapsed);
  }

  final FetchAdScheduleUsecase _fetchAdScheduleUsecase;
  final RotateAdItemUsecase _rotateAdItemUsecase;

  List<AdScheduleItem> _schedule = const [];
  int _currentIndex = 0;

  Timer? _visibleTimer;
  Timer? _hiddenTimer;

  Future<void> _onStarted(AdsStarted event, Emitter<AdsState> emit) async {
    await _loadSchedule(emit);
  }

  Future<void> _onRefreshRequested(
    AdsRefreshRequested event,
    Emitter<AdsState> emit,
  ) async {
    await _loadSchedule(emit);
  }

  Future<void> _loadSchedule(Emitter<AdsState> emit) async {
    try {
      _cancelTimers();
      final schedule = await _fetchAdScheduleUsecase();
      if (schedule.isEmpty) {
        _schedule = const [];
        _currentIndex = 0;
        emit(
          state.copyWith(
            isActive: false,
            isVisible: false,
            currentLink: '',
            clearError: true,
          ),
        );
        return;
      }

      _schedule = schedule;
      _currentIndex = 0;

      emit(
        state.copyWith(
          currentLink: schedule.first.link,
          isActive: true,
          isVisible: true,
          clearError: true,
        ),
      );

      _startVisibleTimer(schedule.first.showSeconds);
    } catch (e) {
      _cancelTimers();
      _schedule = const [];
      _currentIndex = 0;
      emit(
        state.copyWith(
          isActive: false,
          isVisible: false,
          currentLink: '',
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onToggled(AdsToggled event, Emitter<AdsState> emit) {
    if (!state.isActive) {
      return;
    }

    final nextVisible = !state.isVisible;
    emit(state.copyWith(isVisible: nextVisible));
  }

  void _onShowCycleElapsed(AdsShowCycleElapsed event, Emitter<AdsState> emit) {
    if (!state.isActive || _schedule.isEmpty) {
      return;
    }

    emit(state.copyWith(isVisible: false));
    _startHiddenTimer(_schedule[_currentIndex].hideSeconds);
  }

  void _onHideCycleElapsed(AdsHideCycleElapsed event, Emitter<AdsState> emit) {
    if (!state.isActive || _schedule.isEmpty) {
      return;
    }

    final nextIndex = _rotateAdItemUsecase(
      currentIndex: _currentIndex,
      total: _schedule.length,
    );
    _currentIndex = nextIndex;
    final nextItem = _schedule[nextIndex];

    emit(state.copyWith(currentLink: nextItem.link, isVisible: true));

    _startVisibleTimer(nextItem.showSeconds);
  }

  void _startVisibleTimer(int seconds) {
    _hiddenTimer?.cancel();
    _visibleTimer?.cancel();
    _visibleTimer = Timer(Duration(seconds: seconds), () {
      add(const AdsShowCycleElapsed());
    });
  }

  void _startHiddenTimer(int seconds) {
    _visibleTimer?.cancel();
    _hiddenTimer?.cancel();
    _hiddenTimer = Timer(Duration(seconds: seconds), () {
      add(const AdsHideCycleElapsed());
    });
  }

  void _cancelTimers() {
    _visibleTimer?.cancel();
    _hiddenTimer?.cancel();
  }

  @override
  Future<void> close() {
    _cancelTimers();
    return super.close();
  }
}
