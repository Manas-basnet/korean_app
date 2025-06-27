import 'package:flutter/material.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_info.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

class ChapterDetailsDialog extends StatefulWidget {
  final bool isEditing;
  final ChapterInfo? existingChapter;
  final int nextChapterNumber;
  final LanguagePreferenceCubit languageCubit;

  const ChapterDetailsDialog({
    super.key, 
    required this.isEditing,
    this.existingChapter,
    required this.nextChapterNumber,
    required this.languageCubit,
  });

  @override
  State<ChapterDetailsDialog> createState() => ChapterDetailsDialogState();
}

class ChapterDetailsDialogState extends State<ChapterDetailsDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingChapter?.title ?? 'Chapter ${widget.nextChapterNumber}',
    );
    _descriptionController = TextEditingController(
      text: widget.existingChapter?.description ?? '',
    );
    _durationController = TextEditingController(
      text: widget.existingChapter?.duration ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.languageCubit.getLocalizedText(
          korean: widget.isEditing ? '챕터 편집' : '새 챕터',
          english: widget.isEditing ? 'Edit Chapter' : 'New Chapter',
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Chapter Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Duration (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
                hintText: 'e.g., 30 mins',
              ),
            ),
            if (widget.isEditing && widget.existingChapter != null) ...[
              const SizedBox(height: 16),
              Text(
                'Current pages: ${widget.existingChapter!.pageNumbers.length}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            widget.languageCubit.getLocalizedText(
              korean: '취소',
              english: 'Cancel',
            ),
          ),
        ),
        if (widget.isEditing)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop({
                'action': 'save_only',
                'title': _titleController.text.trim(),
                'description': _descriptionController.text.trim(),
                'duration': _durationController.text.trim(),
              });
            },
            child: Text(
              widget.languageCubit.getLocalizedText(
                korean: '저장만',
                english: 'Save Only',
              ),
            ),
          ),
        ElevatedButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isNotEmpty) {
              Navigator.of(context).pop({
                'action': 'select_pages',
                'title': title,
                'description': _descriptionController.text.trim(),
                'duration': _durationController.text.trim(),
              });
            }
          },
          child: Text(
            widget.languageCubit.getLocalizedText(
              korean: widget.isEditing ? '페이지 재선택' : '페이지 선택',
              english: widget.isEditing ? 'Reselect Pages' : 'Select Pages',
            ),
          ),
        ),
      ],
    );
  }
}