import 'package:equatable/equatable.dart';

abstract class AdsEvent extends Equatable {
  const AdsEvent();

  @override
  List<Object?> get props => [];
}

class AdsStarted extends AdsEvent {
  const AdsStarted();
}

class AdsToggled extends AdsEvent {
  const AdsToggled();
}

class AdsShowCycleElapsed extends AdsEvent {
  const AdsShowCycleElapsed();
}

class AdsHideCycleElapsed extends AdsEvent {
  const AdsHideCycleElapsed();
}

class AdsRefreshRequested extends AdsEvent {
  const AdsRefreshRequested();
}
