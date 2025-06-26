import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/features/book_upload/data/models/chapter.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/models/book_item.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/korean_books/korean_books_cubit.dart';
import 'package:korean_language_app/features/books/presentation/pages/pdf_viewer_page.dart';

class ChaptersPage extends StatefulWidget {
  final BookItem book;

  const ChaptersPage({
    super.key,
    required this.book,
  });

  @override
  State<ChaptersPage> createState() => _ChaptersPageState();
}

class _ChaptersPageState extends State<ChaptersPage> {
  StreamSubscription<KoreanBooksState>? _pdfLoadingSubscription;
  String? _currentLoadingChapterId;

  KoreanBooksCubit get _koreanBooksCubit => context.read<KoreanBooksCubit>();
  LanguagePreferenceCubit get _languageCubit => context.read<LanguagePreferenceCubit>();
  SnackBarCubit get _snackBarCubit => context.read<SnackBarCubit>();

  @override
  void dispose() {
    _pdfLoadingSubscription?.cancel();
    super.dispose();
  }

  void _viewChapterPdf(Chapter chapter) {
    _currentLoadingChapterId = chapter.id;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildPdfLoadingDialog(chapter.title),
    );

    _koreanBooksCubit.loadChapterPdf(widget.book.id, chapter.id);
    _listenForPdfLoadingResult(chapter);
  }

  Widget _buildPdfLoadingDialog(String chapterTitle) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            _languageCubit.getLocalizedText(
              korean: '"$chapterTitle" 로딩 중...',
              english: 'Loading "$chapterTitle"...',
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _languageCubit.getLocalizedText(
              korean: '잠시만 기다려주세요',
              english: 'This may take a moment',
            ),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _listenForPdfLoadingResult(Chapter chapter) {
    _pdfLoadingSubscription?.cancel();

    _pdfLoadingSubscription = _koreanBooksCubit.stream.listen((state) {
      if (state.currentOperation.type == KoreanBooksOperationType.loadPdf &&
          state.currentOperation.bookId == chapter.id) {

        if (state.currentOperation.status == KoreanBooksOperationStatus.completed &&
            state.loadedPdfFile != null) {
          Navigator.of(context, rootNavigator: true).pop();
          _verifyAndOpenPdf(state.loadedPdfFile!, chapter.title);
          _pdfLoadingSubscription?.cancel();
        } else if (state.currentOperation.status == KoreanBooksOperationStatus.failed) {
          Navigator.of(context, rootNavigator: true).pop();
          _showRetrySnackBar(
            _getReadableErrorMessage(state.currentOperation.message ?? 'Failed to load PDF'),
            () => _viewChapterPdf(chapter),
          );
          _pdfLoadingSubscription?.cancel();
        }
      }
    });
  }

  String _getReadableErrorMessage(String technicalError) {
    if (technicalError.contains('No internet connection')) {
      return _languageCubit.getLocalizedText(
        korean: '오프라인 상태인 것 같습니다. 연결을 확인하고 다시 시도하세요.',
        english: 'You seem to be offline. Please check your connection and try again.',
      );
    } else if (technicalError.contains('not found')) {
      return _languageCubit.getLocalizedText(
        korean: '죄송합니다. PDF를 찾을 수 없습니다.',
        english: 'Sorry, the chapter PDF could not be found.',
      );
    } else if (technicalError.contains('corrupted') || technicalError.contains('empty')) {
      return _languageCubit.getLocalizedText(
        korean: '죄송합니다. PDF 파일이 손상된 것 같습니다.',
        english: 'Sorry, the PDF file appears to be damaged.',
      );
    } else {
      return _languageCubit.getLocalizedText(
        korean: 'PDF를 로드할 수 없습니다. 다시 시도하세요.',
        english: 'Could not load the PDF. Please try again.',
      );
    }
  }

  void _showRetrySnackBar(String message, VoidCallback onRetry) {
    _snackBarCubit.showErrorLocalized(
      korean: message,
      english: message,
      actionLabelKorean: '다시 시도',
      actionLabelEnglish: 'Retry',
      action: onRetry,
    );
  }

  void _verifyAndOpenPdf(File pdfFile, String chapterTitle) async {
    try {
      final fileExists = await pdfFile.exists();
      final fileSize = fileExists ? await pdfFile.length() : 0;

      if (!fileExists || fileSize == 0) {
        throw Exception('PDF file is empty or does not exist');
      }

      Future.microtask(() => _openPdfViewer(pdfFile, chapterTitle));
    } catch (e) {
      _snackBarCubit.showErrorLocalized(
        korean: '오류: PDF 파일을 열 수 없습니다',
        english: 'Error: PDF file cannot be opened',
      );
    }
  }

  void _openPdfViewer(File pdfFile, String chapterTitle) {
    context.push(
      Routes.pdfViewer,
      extra: PDFViewerScreen(
        pdfFile: pdfFile,
        title: chapterTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sortedChapters = List<Chapter>.from(widget.book.chapters)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.book.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: colorScheme.surface,
      ),
      body: Column(
        children: [
          // Book info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.book.level.getColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.book.level.getColor().withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bar_chart,
                            size: 14,
                            color: widget.book.level.getColor(),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.book.level.toString().split('.').last,
                            style: TextStyle(
                              color: widget.book.level.getColor(),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_stories,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _languageCubit.getLocalizedText(
                              korean: '챕터별',
                              english: 'Chapter-wise',
                            ),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.book.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 16,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _languageCubit.getLocalizedText(
                        korean: '${sortedChapters.length}개 챕터',
                        english: '${sortedChapters.length} chapters',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.book.duration,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chapters list
          Expanded(
            child: sortedChapters.isEmpty
                ? _buildEmptyChaptersView()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedChapters.length,
                    itemBuilder: (context, index) {
                      final chapter = sortedChapters[index];
                      return _buildChapterCard(chapter, index, theme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChaptersView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            _languageCubit.getLocalizedText(
              korean: '챕터가 없습니다',
              english: 'No chapters available',
            ),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _languageCubit.getLocalizedText(
              korean: '챕터를 추가하려면 책을 편집하세요',
              english: 'Edit the book to add chapters',
            ),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(Chapter chapter, int index, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isLoading = _currentLoadingChapterId == chapter.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: colorScheme.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: isLoading ? null : () => _viewChapterPdf(chapter),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Chapter number
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary,
                            ),
                          ),
                        )
                      : Text(
                          '${chapter.order}',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Chapter details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (chapter.description != null && chapter.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          chapter.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.picture_as_pdf,
                          size: 14,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PDF',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (chapter.duration != null && chapter.duration!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            chapter.duration!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Action button
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}