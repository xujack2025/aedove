import 'package:equatable/equatable.dart';

class AdsState extends Equatable {
  const AdsState({
    this.currentLink = '',
    this.isVisible = true,
    this.isActive = false,
    this.errorMessage,
  });

  final String currentLink;
  final bool isVisible;
  final bool isActive;
  final String? errorMessage;

  AdsState copyWith({
    String? currentLink,
    bool? isVisible,
    bool? isActive,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdsState(
      currentLink: currentLink ?? this.currentLink,
      isVisible: isVisible ?? this.isVisible,
      isActive: isActive ?? this.isActive,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [currentLink, isVisible, isActive, errorMessage];
}
