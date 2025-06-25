import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/shared/presentation/update/bloc/update_cubit.dart';
import 'package:restart_app/restart_app.dart';

void showUpdateBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => const _UpdateBottomSheet(),
  );
}

void showRestartBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => const _RestartBottomSheet(),
  );
}

class _UpdateBottomSheet extends StatelessWidget {
  const _UpdateBottomSheet();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UpdateCubit, UpdateState>(
      listenWhen: (previous, current) {
        return current.status == AppUpdateStatus.downloaded;
      },
      listener: (context, state) {
        if (state.status == AppUpdateStatus.downloaded) {
          Navigator.of(context).pop();
          showRestartBottomSheet(context);
        }
      },
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getIconForStatus(state.status),
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getTitleForStatus(state.status),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _getDescriptionForStatus(state.status),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (state.status == AppUpdateStatus.error && state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Error: ${state.errorMessage}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _buildActionButtons(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context, UpdateState state) {
    switch (state.status) {
      case AppUpdateStatus.downloading:
        return Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text('Downloading...', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        );
      case AppUpdateStatus.error:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  context.read<UpdateCubit>().dismissUpdate();
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
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
      default:
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
                child: const Text('Update Now'),
              ),
            ),
          ],
        );
    }
  }

  IconData _getIconForStatus(AppUpdateStatus status) {
    switch (status) {
      case AppUpdateStatus.downloading:
        return Icons.download;
      case AppUpdateStatus.error:
        return Icons.error_outline;
      default:
        return Icons.system_update;
    }
  }

  String _getTitleForStatus(AppUpdateStatus status) {
    switch (status) {
      case AppUpdateStatus.downloading:
        return 'Downloading Update';
      case AppUpdateStatus.error:
        return 'Update Failed';
      default:
        return 'Update Available';
    }
  }

  String _getDescriptionForStatus(AppUpdateStatus status) {
    switch (status) {
      case AppUpdateStatus.downloading:
        return 'Please wait while the update is being downloaded...';
      case AppUpdateStatus.error:
        return 'There was an error downloading the update. Please try again.';
      default:
        return 'A new version of the app is available. Update now to get the latest features and improvements.';
    }
  }
}

class _RestartBottomSheet extends StatelessWidget {
  const _RestartBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.refresh_rounded,
                color: Colors.green,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Update Downloaded',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'The update has been downloaded successfully. Please restart the app to apply the changes and enjoy the latest features.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Later'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _restartApp();
                  },
                  child: const Text('Restart App'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _restartApp() {
    Restart.restartApp();
  }
}