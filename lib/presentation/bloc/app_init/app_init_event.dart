import 'package:equatable/equatable.dart';

abstract class AppInitEvent extends Equatable {
  const AppInitEvent();

  @override
  List<Object?> get props => [];
}

class AppInitStarted extends AppInitEvent {
  const AppInitStarted();
}
