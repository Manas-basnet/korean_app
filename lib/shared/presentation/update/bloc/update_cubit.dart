import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart' as shorebird;
import 'package:equatable/equatable.dart';

part 'update_state.dart';

class UpdateCubit extends Cubit<UpdateState> {
  final shorebird.ShorebirdUpdater _updater;
  bool _isCheckingForUpdates = false;

  UpdateCubit(this._updater) : super(const UpdateState.initial());

  Future<void> checkForUpdates() async {
    if (_isCheckingForUpdates) return;
    
    try {
      _isCheckingForUpdates = true;
      emit(const UpdateState.checking());
      
      final status = await _updater.checkForUpdate();
      
      if (status == shorebird.UpdateStatus.outdated) {
        emit(const UpdateState.available());
      } else {
        emit(const UpdateState.upToDate());
      }
    } catch (error) {
      emit(UpdateState.error(error.toString()));
    } finally {
      _isCheckingForUpdates = false;
    }
  }

  Future<void> downloadUpdate() async {
    try {
      emit(const UpdateState.downloading());
      
      await _updater.update();
      
      emit(const UpdateState.downloaded());
    } on shorebird.UpdateException catch (error) {
      emit(UpdateState.error(error.message));
    } catch (error) {
      emit(UpdateState.error(error.toString()));
    }
  }

  Future<int?> getCurrentPatchNumber() async {
    try {
      final currentPatch = await _updater.readCurrentPatch();
      return currentPatch?.number;
    } catch (error) {
      return null;
    }
  }

  void dismissUpdate() {
    emit(const UpdateState.dismissed());
  }

  void resetState() {
    emit(const UpdateState.initial());
  }
}