import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/shared/presentation/update/bloc/update_cubit.dart';
import 'package:korean_language_app/shared/presentation/update/widgets/update_bottom_sheet.dart';

class UpdateManager extends StatefulWidget {
  final Widget child;

  const UpdateManager({
    super.key,
    required this.child,
  });

  @override
  State<UpdateManager> createState() => _UpdateManagerState();
}

class _UpdateManagerState extends State<UpdateManager> with WidgetsBindingObserver {
  bool _hasShownUpdateThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Check for updates when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Check for updates when app resumes from background
    if (state == AppLifecycleState.resumed) {
      _checkForUpdates();
    }
  }

  void _checkForUpdates() {
    if (!_hasShownUpdateThisSession) {
      context.read<UpdateCubit>().checkForUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UpdateCubit, UpdateState>(
      listener: (context, state) {
        if (state.status == AppUpdateStatus.available && !_hasShownUpdateThisSession) {
          _hasShownUpdateThisSession = true;
          UpdateBottomSheet.show(context);
        } else if (state.status == AppUpdateStatus.dismissed) {
          _hasShownUpdateThisSession = true;
        }
      },
      child: widget.child,
    );
  }
}