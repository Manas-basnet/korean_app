import 'dart:io';
import 'package:flutter/material.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/shared/models/audio_track.dart';
import 'package:korean_language_app/shared/widgets/audio_player.dart';
import 'package:korean_language_app/shared/widgets/audio_recorder.dart';

class MultiAudioPlayerWidget extends StatelessWidget {
  final List<AudioTrack> audioTracks;
  final String? label;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final bool isCompact;
  final double? height;

  const MultiAudioPlayerWidget({
    super.key,
    required this.audioTracks,
    this.label,
    this.onEdit,
    this.onRemove,
    this.isCompact = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (audioTracks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha:0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withValues(alpha:0.3)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.audiotrack_rounded, //TODO: audio track off icon
              size: MediaQuery.of(context).size.width * 0.08,
              color: colorScheme.onSurfaceVariant.withValues(alpha:0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No audio tracks',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha:0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha:0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha:0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null || onEdit != null || onRemove != null) ...[
            Row(
              children: [
                if (label != null)
                  Expanded(
                    child: Text(
                      label!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 18),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: audioTracks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final track = audioTracks[index];
              return AudioPlayerWidget(
                audioUrl: track.audioUrl,
                audioPath: track.audioPath,
                label: track.name,
                isCompact: isCompact,
                height: height,
                minHeight: isCompact ? 35 : 40,
                maxHeight: height ?? (isCompact ? 45 : 60),
              );
            },
          ),
        ],
      ),
    );
  }
}

class MultiAudioTrackManagerWidget extends StatefulWidget {
  final List<AudioTrackUploadData> audioTracks;
  final Function(List<AudioTrackUploadData>) onAudioTracksChanged;
  final String label;

  const MultiAudioTrackManagerWidget({
    super.key,
    required this.audioTracks,
    required this.onAudioTracksChanged,
    required this.label,
  });

  @override
  State<MultiAudioTrackManagerWidget> createState() => _MultiAudioTrackManagerWidgetState();
}

class _MultiAudioTrackManagerWidgetState extends State<MultiAudioTrackManagerWidget> {
  late List<AudioTrackUploadData> _audioTracks;

  @override
  void initState() {
    super.initState();
    _audioTracks = List.from(widget.audioTracks);
  }

  @override
  void didUpdateWidget(MultiAudioTrackManagerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioTracks != widget.audioTracks) {
      _audioTracks = List.from(widget.audioTracks);
    }
  }

  void _addAudioTrack(File audioFile, String trackName) {
    final newTrack = AudioTrackUploadData(
      name: trackName,
      audioFile: audioFile,
      order: _audioTracks.length,
    );
    
    setState(() {
      _audioTracks.add(newTrack);
    });
    
    widget.onAudioTracksChanged(_audioTracks);
  }

  void _removeAudioTrack(int index) {
    setState(() {
      _audioTracks.removeAt(index);
      // Update order for remaining tracks
      for (int i = 0; i < _audioTracks.length; i++) {
        _audioTracks[i] = _audioTracks[i].copyWith(order: i);
      }
    });
    
    widget.onAudioTracksChanged(_audioTracks);
  }

  void _editAudioTrack(int index, String newName) {
    setState(() {
      _audioTracks[index] = _audioTracks[index].copyWith(name: newName);
    });
    
    widget.onAudioTracksChanged(_audioTracks);
  }

  Future<void> _showAddAudioDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _AddAudioTrackDialog(
        onAudioTrackAdded: _addAudioTrack,
        trackNumber: _audioTracks.length + 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha:0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.audiotrack_rounded,
                color: colorScheme.tertiary,
                size: MediaQuery.of(context).size.width * 0.06,
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              Expanded(
                child: Text(
                  '${widget.label} (${_audioTracks.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddAudioDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.tertiary,
                  foregroundColor: colorScheme.onTertiary,
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.03,
                    vertical: MediaQuery.of(context).size.height * 0.01,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          
          if (_audioTracks.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06),
              decoration: BoxDecoration(
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha:0.2),
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surface,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.audiotrack_rounded, //TODO: audio track off 
                    size: MediaQuery.of(context).size.width * 0.1,
                    color: colorScheme.onSurface.withValues(alpha:0.4),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Text(
                    'No audio tracks added',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha:0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                  Text(
                    'Add audio tracks to enhance the reading experience',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha:0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _audioTracks.length,
              separatorBuilder: (context, index) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.01,
              ),
              itemBuilder: (context, index) {
                final track = _audioTracks[index];
                return Container(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha:0.2),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: colorScheme.surface,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width * 0.08,
                        height: MediaQuery.of(context).size.width * 0.08,
                        decoration: BoxDecoration(
                          color: colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onTertiary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: MediaQuery.of(context).size.height * 0.002),
                            Text(
                              'File: ${track.audioFile.path.split('/').last}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha:0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: colorScheme.onSurface.withValues(alpha:0.6),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditNameDialog(index);
                          } else if (value == 'delete') {
                            _removeAudioTrack(index);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Rename'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog(int index) async {
    final controller = TextEditingController(text: _audioTracks[index].name);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Audio Track'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Track Name',
            hintText: 'Enter track name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _editAudioTrack(index, result);
    }
  }
}

class _AddAudioTrackDialog extends StatefulWidget {
  final Function(File audioFile, String trackName) onAudioTrackAdded;
  final int trackNumber;

  const _AddAudioTrackDialog({
    required this.onAudioTrackAdded,
    required this.trackNumber,
  });

  @override
  State<_AddAudioTrackDialog> createState() => _AddAudioTrackDialogState();
}

class _AddAudioTrackDialogState extends State<_AddAudioTrackDialog> {
  final _nameController = TextEditingController();
  File? _selectedAudioFile;

  @override
  void initState() {
    super.initState();
    _nameController.text = 'Audio Track ${widget.trackNumber}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onAudioSelected(File audioFile) {
    setState(() {
      _selectedAudioFile = audioFile;
    });
  }

  void _saveAudioTrack() {
    if (_selectedAudioFile != null && _nameController.text.trim().isNotEmpty) {
      widget.onAudioTrackAdded(_selectedAudioFile!, _nameController.text.trim());
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.7,
          maxWidth: mediaQuery.size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha:0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.audiotrack_rounded,
                    color: theme.colorScheme.tertiary,
                    size: mediaQuery.size.width * 0.06,
                  ),
                  SizedBox(width: mediaQuery.size.width * 0.02),
                  Expanded(
                    child: Text(
                      'Add Audio Track',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.outline.withValues(alpha:0.1),
                    ),
                  ),
                ],
              ),
            ),
            
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Track Name',
                        hintText: 'Enter audio track name',
                        prefixIcon: const Icon(Icons.label_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                    ),
                    SizedBox(height: mediaQuery.size.height * 0.02),
                    AudioRecorderWidget(
                      onAudioSelected: _onAudioSelected,
                      label: 'Record or select audio file for this track',
                    ),
                  ],
                ),
              ),
            ),
            
            Container(
              padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha:0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: mediaQuery.size.width * 0.04,
                        vertical: mediaQuery.size.height * 0.015,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: mediaQuery.size.width * 0.02),
                  ElevatedButton(
                    onPressed: _selectedAudioFile != null && _nameController.text.trim().isNotEmpty
                        ? _saveAudioTrack 
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.tertiary,
                      foregroundColor: theme.colorScheme.onTertiary,
                      padding: EdgeInsets.symmetric(
                        horizontal: mediaQuery.size.width * 0.04,
                        vertical: mediaQuery.size.height * 0.015,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Add Track'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}