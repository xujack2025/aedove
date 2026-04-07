import 'package:equatable/equatable.dart';

enum AppInitStatus { initial, loading, success, failure }

class AppInitState extends Equatable {
  const AppInitState({this.status = AppInitStatus.initial, this.errorMessage});

  final AppInitStatus status;
  final String? errorMessage;

  AppInitState copyWith({
    AppInitStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AppInitState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
