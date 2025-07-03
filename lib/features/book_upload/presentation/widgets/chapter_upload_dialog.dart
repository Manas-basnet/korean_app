import 'dart:io';
import 'package:flutter/material.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/file_upload_cubit.dart';
import 'package:korean_language_app/features/book_upload/presentation/widgets/multi_audio_player_widget.dart';
import 'package:korean_language_app/shared/models/audio_track.dart';
import 'package:korean_language_app/shared/models/book_related/chapter.dart';

class ChapterUploadDialog extends StatefulWidget {
  final int chapterNumber;
  final FileUploadCubit fileUploadCubit;
  final ChapterUploadData? existingChapter;
  final List<AudioTrack>? existingAudioTracks;
  final Chapter? originalChapter;
  final List<String>? existingChapterTitles;

  const ChapterUploadDialog({
    super.key,
    required this.chapterNumber,
    required this.fileUploadCubit,
    this.existingChapter,
    this.existingAudioTracks,
    this.originalChapter,
    this.existingChapterTitles,
  });

  @override
  State<ChapterUploadDialog> createState() => _ChapterUploadDialogState();
}

class _ChapterUploadDialogState extends State<ChapterUploadDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;

  File? _selectedFile;
  String? _fileName;
  bool _fileChanged = false;
  List<AudioTrackUploadData> _audioTracks = [];
  bool _showExistingAudio = true;
  List<AudioTrack> _currentExistingAudio = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAudioTracks();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(
      text: widget.existingChapter?.title ?? 'Chapter ${widget.chapterNumber}',
    );
    _descriptionController = TextEditingController(
      text: widget.existingChapter?.description ?? '',
    );
    _durationController = TextEditingController(
      text: widget.existingChapter?.duration ?? '10 mins',
    );

    if (widget.existingChapter?.pdfFile != null) {
      _selectedFile = widget.existingChapter!.pdfFile;
      _fileName = _selectedFile!.path.split('/').last;
    } else if (widget.originalChapter?.pdfUrl != null) {
      _fileName = 'Current chapter PDF';
    } else if (widget.existingChapter != null) {
      _fileName = 'Chapter PDF file';
    }
  }

  void _initializeAudioTracks() {
    // Priority: 1. Existing chapter data, 2. Original chapter data, 3. Empty
    if (widget.existingChapter != null && widget.existingChapter!.audioTracks.isNotEmpty) {
      // If editing an existing chapter with new audio tracks
      _audioTracks = List.from(widget.existingChapter!.audioTracks);
      _showExistingAudio = false;
      _currentExistingAudio = [];
    } else if (widget.originalChapter != null && widget.originalChapter!.audioTracks.isNotEmpty) {
      // If editing and original chapter has audio tracks
      _currentExistingAudio = List.from(widget.originalChapter!.audioTracks);
      _showExistingAudio = true;
      _audioTracks = [];
    } else if (widget.existingAudioTracks != null && widget.existingAudioTracks!.isNotEmpty) {
      // Fallback to provided existing audio tracks
      _currentExistingAudio = List.from(widget.existingAudioTracks!);
      _showExistingAudio = true;
      _audioTracks = [];
    } else {
      // No existing audio
      _showExistingAudio = false;
      _audioTracks = [];
      _currentExistingAudio = [];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await widget.fileUploadCubit.pickPdfFile();
    if (file != null) {
      setState(() {
        _selectedFile = file;
        _fileName = file.path.split('/').last;
        _fileChanged = true;
      });
    }
  }

  void _onAudioTracksChanged(List<AudioTrackUploadData> audioTracks) {
    setState(() {
      _audioTracks = audioTracks;
      _showExistingAudio = false;
      _currentExistingAudio = []; // Clear existing audio when new ones are added
    });
  }

  void _onEditExistingAudio() {
    setState(() {
      _showExistingAudio = false;
      _audioTracks.clear();
      _currentExistingAudio = []; // Clear existing audio to show editor
    });
  }

  void _saveChapter() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    // Determine if this chapter has been modified
    bool isModified = widget.existingChapter == null ||
        widget.existingChapter!.title != _titleController.text ||
        widget.existingChapter!.description != _descriptionController.text ||
        widget.existingChapter!.duration != _durationController.text ||
        _fileChanged ||
        !_showExistingAudio ||
        _audioTracks.isNotEmpty;

    File? pdfFileToUpload;
    if (_fileChanged && _selectedFile != null) {
      pdfFileToUpload = _selectedFile;
    } else if (!_fileChanged && widget.existingChapter?.pdfFile != null) {
      pdfFileToUpload = widget.existingChapter!.pdfFile;
    }

    // Only include audio tracks if they have been modified
    List<AudioTrackUploadData> audioTracksToSave = [];
    if (!_showExistingAudio && _audioTracks.isNotEmpty) {
      audioTracksToSave = _audioTracks;
    }

    final chapter = ChapterUploadData(
      title: _titleController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      duration: _durationController.text.isEmpty ? null : _durationController.text,
      pdfFile: pdfFileToUpload,
      audioTracks: audioTracksToSave,
      order: widget.chapterNumber,
      isNewOrModified: isModified,
      existingId: widget.existingChapter?.existingId ?? widget.originalChapter?.id,
    );

    Navigator.of(context).pop(chapter);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.sizeOf(context);
    
    final hasExistingPdf = _selectedFile != null || 
                          widget.originalChapter?.pdfUrl != null || 
                          widget.existingChapter?.pdfFile != null;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.height * 0.9,
          maxWidth: mediaQuery.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(mediaQuery.width * 0.04),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    color: theme.colorScheme.primary,
                    size: mediaQuery.width * 0.06,
                  ),
                  SizedBox(width: mediaQuery.width * 0.02),
                  Expanded(
                    child: Text(
                      widget.existingChapter != null ? 'Edit Chapter' : 'Add Chapter',
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
                      backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
            
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(mediaQuery.width * 0.04),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Chapter Title',
                          hintText: 'Enter chapter title',
                          prefixIcon: const Icon(Icons.title_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          errorMaxLines: 2, // Allow multi-line error messages
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          
                          // Check for duplicate titles
                          if (widget.existingChapterTitles != null) {
                            final normalizedTitle = value.toLowerCase().trim();
                            if (widget.existingChapterTitles!.contains(normalizedTitle)) {
                              return 'A chapter with this title already exists. Please choose a different title.';
                            }
                          }
                          
                          // Check title length
                          if (value.trim().length < 2) {
                            return 'Title must be at least 2 characters long';
                          }
                          
                          if (value.trim().length > 100) {
                            return 'Title must be less than 100 characters';
                          }
                          
                          return null;
                        },
                        onChanged: (value) {
                          // Real-time validation feedback
                          if (widget.existingChapterTitles != null) {
                            final normalizedTitle = value.toLowerCase().trim();
                            if (widget.existingChapterTitles!.contains(normalizedTitle) && value.isNotEmpty) {
                              // Show immediate feedback without blocking typing
                              setState(() {
                                // You could add a visual indicator here if needed
                              });
                            }
                          }
                        },
                      ),
                      SizedBox(height: mediaQuery.height * 0.02),
                      
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'Enter chapter description',
                          prefixIcon: const Icon(Icons.description_rounded),
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: mediaQuery.height * 0.02),
                      
                      TextFormField(
                        controller: _durationController,
                        decoration: InputDecoration(
                          labelText: 'Duration (Optional)',
                          hintText: '10 mins',
                          prefixIcon: const Icon(Icons.timer_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                        ),
                      ),
                      SizedBox(height: mediaQuery.height * 0.02),
                      
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(mediaQuery.width * 0.04),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _fileChanged || hasExistingPdf
                                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                : theme.colorScheme.outline.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: _fileChanged || hasExistingPdf
                              ? theme.colorScheme.primary.withValues(alpha: 0.05)
                              : theme.colorScheme.surface,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(mediaQuery.width * 0.02),
                                  decoration: BoxDecoration(
                                    color: _fileChanged || hasExistingPdf
                                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                        : theme.colorScheme.outline.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _fileChanged || hasExistingPdf ? Icons.check_circle_rounded : Icons.picture_as_pdf_rounded,
                                    color: _fileChanged || hasExistingPdf
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    size: mediaQuery.width * 0.05,
                                  ),
                                ),
                                SizedBox(width: mediaQuery.width * 0.03),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fileName ?? 
                                        (widget.existingChapter?.pdfFile != null 
                                            ? widget.existingChapter!.pdfFile!.path.split('/').last
                                            : 'No PDF selected'),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: _fileChanged || hasExistingPdf
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                          fontWeight: _fileChanged || hasExistingPdf ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                      if (_fileChanged)
                                        Text(
                                          'New PDF file ready for upload',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                          ),
                                        )
                                      else if (hasExistingPdf && !_fileChanged)
                                        Text(
                                          widget.existingChapter?.pdfFile != null 
                                              ? 'PDF file attached to chapter'
                                              : 'Keep current PDF or select new one',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: mediaQuery.height * 0.015),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _pickFile,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: Text(hasExistingPdf && !_fileChanged
                                    ? 'Change PDF File' 
                                    : 'Select PDF File'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: EdgeInsets.symmetric(
                                    vertical: mediaQuery.height * 0.015,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: mediaQuery.height * 0.02),
                      
                      if (_showExistingAudio && _currentExistingAudio.isNotEmpty) ...[
                        MultiAudioPlayerWidget(
                          audioTracks: _currentExistingAudio,
                          label: 'Current Audio Tracks (${_currentExistingAudio.length})',
                          onEdit: _onEditExistingAudio,
                        ),
                      ] else
                        MultiAudioTrackManagerWidget(
                          audioTracks: _audioTracks,
                          onAudioTracksChanged: _onAudioTracksChanged,
                          label: 'Chapter Audio Tracks',
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            Container(
              padding: EdgeInsets.all(mediaQuery.width * 0.04),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
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
                        horizontal: mediaQuery.width * 0.04,
                        vertical: mediaQuery.height * 0.015,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: mediaQuery.width * 0.02),
                  ElevatedButton(
                    onPressed: _saveChapter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: EdgeInsets.symmetric(
                        horizontal: mediaQuery.width * 0.04,
                        vertical: mediaQuery.height * 0.015,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Save Chapter'),
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