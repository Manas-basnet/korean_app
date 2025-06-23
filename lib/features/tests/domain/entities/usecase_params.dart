import 'package:equatable/equatable.dart';

class CheckTestPermissionParams extends Equatable {
  final String testId;
  final String? testCreatorUid;

  const CheckTestPermissionParams({
    required this.testId,
    this.testCreatorUid,
  });

  @override
  List<Object?> get props => [testId, testCreatorUid];
}




