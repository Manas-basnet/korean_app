// lib/shared/presentation/update/bloc/update_state.dart
part of 'update_cubit.dart';

enum AppUpdateStatus {
  initial,
  checking,
  available,
  downloading,
  downloaded,
  upToDate,
  dismissed,
  error,
}

class UpdateState extends Equatable {
  final AppUpdateStatus status;
  final String? errorMessage;

  const UpdateState._({
    required this.status,
    this.errorMessage,
  });

  const UpdateState.initial() : this._(status: AppUpdateStatus.initial);
  const UpdateState.checking() : this._(status: AppUpdateStatus.checking);
  const UpdateState.available() : this._(status: AppUpdateStatus.available);
  const UpdateState.downloading() : this._(status: AppUpdateStatus.downloading);
  const UpdateState.downloaded() : this._(status: AppUpdateStatus.downloaded);
  const UpdateState.upToDate() : this._(status: AppUpdateStatus.upToDate);
  const UpdateState.dismissed() : this._(status: AppUpdateStatus.dismissed);
  const UpdateState.error(String message) : this._(status: AppUpdateStatus.error, errorMessage: message);

  @override
  List<Object?> get props => [status, errorMessage];
}