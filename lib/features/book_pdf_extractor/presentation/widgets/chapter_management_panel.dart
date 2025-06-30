import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/shared/models/chapter_info.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

class ChapterManagementPanel extends StatelessWidget {
  final List<ChapterInfo> chapters;
  final int totalPages;
  final Function(int chapterNumber) onCreateChapter;
  final Function(int chapterNumber) onEditChapter;
  final Function(int chapterNumber) onDeleteChapter;

  const ChapterManagementPanel({
    super.key,
    required this.chapters,
    required this.totalPages,
    required this.onCreateChapter,
    required this.onEditChapter,
    required this.onDeleteChapter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(color: colorScheme.outline.withValues(alpha:0.3)),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              border: Border(
                bottom: BorderSide(color: colorScheme.outline.withValues(alpha:0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_stories, color: colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    languageCubit.getLocalizedText(
                      korean: '챕터 관리',
                      english: 'Chapter Management',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stats
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  context,
                  languageCubit.getLocalizedText(korean: '총 페이지', english: 'Total Pages'),
                  totalPages.toString(),
                  Icons.description,
                ),
                _buildStatCard(
                  context,
                  languageCubit.getLocalizedText(korean: '챕터', english: 'Chapters'),
                  chapters.length.toString(),
                  Icons.auto_stories,
                ),
                _buildStatCard(
                  context,
                  languageCubit.getLocalizedText(korean: '사용된 페이지', english: 'Used Pages'),
                  _getTotalUsedPages().toString(),
                  Icons.check_circle,
                ),
              ],
            ),
          ),

          // Add chapter button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCreateChapterDialog(context),
                icon: const Icon(Icons.add),
                label: Text(
                  languageCubit.getLocalizedText(
                    korean: '새 챕터',
                    english: 'New Chapter',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Chapters list
          Expanded(
            child: chapters.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      return _buildChapterCard(context, chapter);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              languageCubit.getLocalizedText(
                korean: '아직 챕터가 없습니다',
                english: 'No chapters yet',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              languageCubit.getLocalizedText(
                korean: '새 챕터를 만들어 페이지를 선택하세요',
                english: 'Create a new chapter and select pages',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterCard(BuildContext context, ChapterInfo chapter) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getChapterColor(chapter.chapterNumber),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      chapter.chapterNumber.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${chapter.pageCount} pages',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEditChapter(chapter.chapterNumber);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(context, chapter);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (chapter.description != null) ...[
              const SizedBox(height: 8),
              Text(
                chapter.description!,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getChapterColor(int chapterNumber) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[(chapterNumber - 1) % colors.length];
  }

  int _getTotalUsedPages() {
    return chapters.fold(0, (sum, chapter) => sum + chapter.pageCount);
  }

  void _showCreateChapterDialog(BuildContext context) {
    final nextChapterNumber = (chapters.isNotEmpty ? chapters.last.chapterNumber : 0) + 1;
    onCreateChapter(nextChapterNumber);
  }

  void _showDeleteConfirmation(BuildContext context, ChapterInfo chapter) {
    final languageCubit = context.read<LanguagePreferenceCubit>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageCubit.getLocalizedText(
            korean: '챕터 삭제',
            english: 'Delete Chapter',
          ),
        ),
        content: Text(
          languageCubit.getLocalizedText(
            korean: '챕터 "${chapter.title}"를 삭제하시겠습니까?',
            english: 'Are you sure you want to delete chapter "${chapter.title}"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              languageCubit.getLocalizedText(
                korean: '취소',
                english: 'Cancel',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDeleteChapter(chapter.chapterNumber);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              languageCubit.getLocalizedText(
                korean: '삭제',
                english: 'Delete',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// lib/features/book_upload/presentation/widgets/page_selection_floating_panel.dart
class PageSelectionFloatingPanel extends StatefulWidget {
  final int selectedCount;
  final int? chapterNumber;
  final VoidCallback onCancel;
  final Function(String title, String? description, String? duration) onSave;

  const PageSelectionFloatingPanel({
    super.key,
    required this.selectedCount,
    this.chapterNumber,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<PageSelectionFloatingPanel> createState() => _PageSelectionFloatingPanelState();
}

class _PageSelectionFloatingPanelState extends State<PageSelectionFloatingPanel> {
  bool _isExpanded = false;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.chapterNumber != null) {
      _titleController.text = 'Chapter ${widget.chapterNumber}';
    }
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: _isExpanded ? 400 : 300,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.primary, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with selection info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      languageCubit.getLocalizedText(
                        korean: '${widget.selectedCount}개 페이지 선택됨',
                        english: '${widget.selectedCount} pages selected',
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            // Expanded form
            if (_isExpanded) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: languageCubit.getLocalizedText(
                          korean: '챕터 제목',
                          english: 'Chapter Title',
                        ),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: languageCubit.getLocalizedText(
                          korean: '설명 (선택사항)',
                          english: 'Description (Optional)',
                        ),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.description),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _durationController,
                      decoration: InputDecoration(
                        labelText: languageCubit.getLocalizedText(
                          korean: '예상 시간 (선택사항)',
                          english: 'Duration (Optional)',
                        ),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.timer),
                        hintText: '30 mins',
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      child: Text(
                        languageCubit.getLocalizedText(
                          korean: '취소',
                          english: 'Cancel',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.selectedCount > 0 ? _handleSave : null,
                      child: Text(
                        languageCubit.getLocalizedText(
                          korean: '저장',
                          english: 'Save',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSave() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a chapter title')),
      );
      return;
    }

    widget.onSave(
      title,
      _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      _durationController.text.trim().isEmpty ? null : _durationController.text.trim(),
    );
  }
}