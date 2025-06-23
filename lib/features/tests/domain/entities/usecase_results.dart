import 'package:equatable/equatable.dart';



class TestPermissionResult extends Equatable {
  final bool canEdit;
  final bool canDelete;
  final bool canView;
  final String reason;

  const TestPermissionResult({
    required this.canEdit,
    required this.canDelete,
    required this.canView,
    this.reason = '',
  });

  @override
  List<Object?> get props => [canEdit, canDelete, canView, reason];
}





