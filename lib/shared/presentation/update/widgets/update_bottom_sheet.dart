import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/shared/presentation/update/bloc/update_cubit.dart';

class UpdateBottomSheet extends StatelessWidget {
  const UpdateBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const UpdateBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocConsumer<UpdateCubit, UpdateState>(
      listener: (context, state) {
        if (state.status == AppUpdateStatus.downloaded) {
          _showRestartDialog(context);
        }
      },
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    size: 32,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'App Update Available',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  _getDescription(state),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Progress indicator (show when downloading)
                if (state.status == AppUpdateStatus.downloading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                ],

                // Action buttons
                _buildActionButtons(context, state, colorScheme),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getDescription(UpdateState state) {
    switch (state.status) {
      case AppUpdateStatus.available:
        return 'A new version is available with bug fixes and improvements. Update now to get the latest features.';
      case AppUpdateStatus.downloading:
        return 'Downloading update... Please wait.';
      case AppUpdateStatus.error:
        return 'Failed to download update: ${state.errorMessage}';
      default:
        return 'Checking for updates...';
    }
  }

  Widget _buildActionButtons(BuildContext context, UpdateState state, ColorScheme colorScheme) {
    if (state.status == AppUpdateStatus.downloading) {
      return const SizedBox(height: 48); // Placeholder to maintain height
    }

    if (state.status == AppUpdateStatus.error) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                context.read<UpdateCubit>().dismissUpdate();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => context.read<UpdateCubit>().downloadUpdate(),
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              context.read<UpdateCubit>().dismissUpdate();
              Navigator.of(context).pop();
            },
            child: const Text('Later'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => context.read<UpdateCubit>().downloadUpdate(),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: const Text('Update Now'),
          ),
        ),
      ],
    );
  }

  void _showRestartDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Update Complete'),
        content: const Text('The app needs to restart to apply the update.'),
        actions: [
          ElevatedButton(
            onPressed: () => _restartApp(context),
            child: const Text('Restart Now'),
          ),
        ],
      ),
    );
  }

  void _restartApp(BuildContext context) {
    Navigator.of(context).pop(); // Close dialog
    Navigator.of(context).pop(); // Close bottom sheet
    
    // Force app restart by recreating the entire widget tree
    final navigator = Navigator.of(context);
    navigator.pushNamedAndRemoveUntil('/', (route) => false);
    
    // Alternative: You could also use a restart package or 
    // implement a custom restart mechanism
  }
}