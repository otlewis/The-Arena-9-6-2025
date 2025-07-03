import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/user.dart';

part 'app_state.freezed.dart';

/// Global application state
@freezed
class AppState with _$AppState {
  const factory AppState({
    @Default(false) bool isLoading,
    @Default(false) bool isAuthenticated,
    User? currentUser,
    @Default(false) bool isOnline,
    String? lastError,
  }) = _AppState;
}

/// Loading state for UI components
@freezed
class LoadingState with _$LoadingState {
  const factory LoadingState.initial() = _Initial;
  const factory LoadingState.loading() = _Loading;
  const factory LoadingState.success() = _Success;
  const factory LoadingState.error(String message) = _Error;
}