import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_word.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_meaning.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_example.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/widgets/audio_player.dart';

class WordStudyWidget extends StatefulWidget {
  final VocabularyWord word;
  final int wordIndex;
  final int totalWords;
  final LanguagePreferenceCubit languageCubit;

  const WordStudyWidget({
    super.key,
    required this.word,
    required this.wordIndex,
    required this.totalWords,
    required this.languageCubit,
  });

  @override
  State<WordStudyWidget> createState() => _WordStudyWidgetState();
}

class _WordStudyWidgetState extends State<WordStudyWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showMeanings = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _showMeanings = _tabController.index == 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWordHeader(theme, colorScheme, screenSize),
                    
                    if (widget.word.hasImage || widget.word.hasAudio) ...[
                      const SizedBox(height: 24),
                      _buildMediaSection(theme, colorScheme, screenSize),
                    ],
                    
                    const SizedBox(height: 32),
                    _buildTabBar(theme, colorScheme),
                    
                    const SizedBox(height: 24),
                    _buildTabContent(theme, colorScheme, screenSize),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordHeader(ThemeData theme, ColorScheme colorScheme, Size screenSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${widget.wordIndex + 1} / ${widget.totalWords}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Text(
          widget.word.word,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            fontSize: screenSize.width * 0.08,
          ),
        ),
        
        if (widget.word.hasPronunciation) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.word.pronunciation!,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMediaSection(ThemeData theme, ColorScheme colorScheme, Size screenSize) {
    return Row(
      children: [
        if (widget.word.hasImage) ...[
          Expanded(
            flex: widget.word.hasAudio ? 3 : 1,
            child: _buildWordImage(screenSize, colorScheme),
          ),
          if (widget.word.hasAudio) const SizedBox(width: 16),
        ],
        if (widget.word.hasAudio)
          Expanded(
            flex: 2,
            child: _buildWordAudio(),
          ),
      ],
    );
  }

  Widget _buildWordImage(Size screenSize, ColorScheme colorScheme) {
    return Container(
      height: screenSize.height * 0.2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: _buildImageContent(colorScheme),
      ),
    );
  }

  Widget _buildImageContent(ColorScheme colorScheme) {
    if (widget.word.imagePath != null && widget.word.imagePath!.isNotEmpty) {
      return Image.file(
        File(widget.word.imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          if (widget.word.imageUrl != null && widget.word.imageUrl!.isNotEmpty) {
            return _buildNetworkImage();
          }
          return _buildImagePlaceholder(colorScheme);
        },
      );
    }
    
    if (widget.word.imageUrl != null && widget.word.imageUrl!.isNotEmpty) {
      return _buildNetworkImage();
    }
    
    return _buildImagePlaceholder(colorScheme);
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: widget.word.imageUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) => _buildImagePlaceholder(
        Theme.of(context).colorScheme,
      ),
    );
  }

  Widget _buildImagePlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildWordAudio() {
    return AudioPlayerWidget(
      audioUrl: widget.word.audioUrl,
      audioPath: widget.word.audioPath,
      label: widget.languageCubit.getLocalizedText(
        korean: '단어 발음',
        english: 'Word Pronunciation',
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: colorScheme.onPrimary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            text: widget.languageCubit.getLocalizedText(
              korean: '의미',
              english: 'Meanings',
            ),
          ),
          Tab(
            text: widget.languageCubit.getLocalizedText(
              korean: '예문',
              english: 'Examples',
            ),
          ),
          Tab(
            text: widget.languageCubit.getLocalizedText(
              korean: '정보',
              english: 'Info',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(ThemeData theme, ColorScheme colorScheme, Size screenSize) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        switch (_tabController.index) {
          case 0:
            return _buildMeaningsTab(theme, colorScheme, screenSize);
          case 1:
            return _buildExamplesTab(theme, colorScheme, screenSize);
          case 2:
            return _buildInfoTab(theme, colorScheme, screenSize);
          default:
            return _buildMeaningsTab(theme, colorScheme, screenSize);
        }
      },
    );
  }

  Widget _buildMeaningsTab(ThemeData theme, ColorScheme colorScheme, Size screenSize) {
    if (!widget.word.hasMeanings) {
      return _buildEmptyState(
        theme,
        colorScheme,
        Icons.book_outlined,
        widget.languageCubit.getLocalizedText(
          korean: '의미가 없습니다',
          english: 'No meanings available',
        ),
      );
    }

    return Column(
      children: widget.word.meanings.asMap().entries.map((entry) {
        final index = entry.key;
        final meaning = entry.value;
        return _buildMeaningCard(meaning, index, theme, colorScheme, screenSize);
      }).toList(),
    );
  }

  Widget _buildMeaningCard(WordMeaning meaning, int index, ThemeData theme, ColorScheme colorScheme, Size screenSize) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      meaning.language.flag,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      meaning.language.name.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            meaning.meaning,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
              height: 1.4,
            ),
          ),
          
          if (meaning.hasAudio) ...[
            const SizedBox(height: 12),
            AudioPlayerWidget(
              audioUrl: meaning.audioUrl,
              audioPath: meaning.audioPath,
              label: widget.languageCubit.getLocalizedText(
                korean: '의미 발음',
                english: 'Meaning Pronunciation',
              ),
              height: 40,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExamplesTab(ThemeData theme, ColorScheme colorScheme, Size screenSize) {
    if (!widget.word.hasExamples) {
      return _buildEmptyState(
        theme,
        colorScheme,
        Icons.format_quote,
        widget.languageCubit.getLocalizedText(
          korean: '예문이 없습니다',
          english: 'No examples available',
        ),
      );
    }

    return Column(
      children: widget.word.examples.asMap().entries.map((entry) {
        final index = entry.key;
        final example = entry.value;
        return _buildExampleCard(example, index, theme, colorScheme, screenSize);
      }).toList(),
    );
  }

  Widget _buildExampleCard(WordExample example, int index, ThemeData theme, ColorScheme colorScheme, Size screenSize) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.format_quote,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              example.example,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          
          if (example.hasTranslation) ...[
            const SizedBox(height: 8),
            Text(
              example.translation!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          
          if (example.hasAudio) ...[
            const SizedBox(height: 12),
            AudioPlayerWidget(
              audioUrl: example.audioUrl,
              audioPath: example.audioPath,
              label: widget.languageCubit.getLocalizedText(
                korean: '예문 발음',
                english: 'Example Pronunciation',
              ),
              height: 40,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoTab(ThemeData theme, ColorScheme colorScheme, Size screenSize) {
    return Column(
      children: [
        _buildInfoCard(
          theme,
          colorScheme,
          Icons.translate,
          widget.languageCubit.getLocalizedText(
            korean: '단어',
            english: 'Word',
          ),
          widget.word.word,
        ),
        
        if (widget.word.hasPronunciation)
          _buildInfoCard(
            theme,
            colorScheme,
            Icons.record_voice_over,
            widget.languageCubit.getLocalizedText(
              korean: '발음',
              english: 'Pronunciation',
            ),
            widget.word.pronunciation!,
          ),
        
        _buildInfoCard(
          theme,
          colorScheme,
          Icons.book,
          widget.languageCubit.getLocalizedText(
            korean: '의미 개수',
            english: 'Number of Meanings',
          ),
          widget.word.meaningCount.toString(),
        ),
        
        _buildInfoCard(
          theme,
          colorScheme,
          Icons.format_quote,
          widget.languageCubit.getLocalizedText(
            korean: '예문 개수',
            english: 'Number of Examples',
          ),
          widget.word.exampleCount.toString(),
        ),
        
        _buildInfoCard(
          theme,
          colorScheme,
          Icons.audio_file,
          widget.languageCubit.getLocalizedText(
            korean: '음성 파일',
            english: 'Audio Available',
          ),
          widget.word.hasAudio 
            ? widget.languageCubit.getLocalizedText(korean: '있음', english: 'Yes')
            : widget.languageCubit.getLocalizedText(korean: '없음', english: 'No'),
        ),
        
        _buildInfoCard(
          theme,
          colorScheme,
          Icons.image,
          widget.languageCubit.getLocalizedText(
            korean: '이미지',
            english: 'Image Available',
          ),
          widget.word.hasImage 
            ? widget.languageCubit.getLocalizedText(korean: '있음', english: 'Yes')
            : widget.languageCubit.getLocalizedText(korean: '없음', english: 'No'),
        ),
      ],
    );
  }

  Widget _buildInfoCard(ThemeData theme, ColorScheme colorScheme, IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme, IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}