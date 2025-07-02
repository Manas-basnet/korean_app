import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/file_upload_cubit.dart';
import 'package:korean_language_app/features/book_upload/presentation/widgets/multi_audio_player_widget.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/book_upload_type.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/enums/file_upload_type.dart';
import 'package:korean_language_app/shared/models/audio_track.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class UploadTypeSelectionWidget extends StatelessWidget {
  final BookUploadType uploadType;
  final Function(BookUploadType) onUploadTypeChanged;
  final bool isEnabled;

  const UploadTypeSelectionWidget({
    super.key,
    required this.uploadType,
    required this.onUploadTypeChanged,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Type',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          Row(
            children: BookUploadType.values.map((type) {
              final isSelected = uploadType == type;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: type == BookUploadType.values.first 
                        ? MediaQuery.of(context).size.width * 0.02 
                        : 0,
                  ),
                  child: InkWell(
                    onTap: isEnabled ? () => onUploadTypeChanged(type) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type == BookUploadType.singlePdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.auto_stories_rounded,
                            size: MediaQuery.of(context).size.width * 0.08,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                          Text(
                            type.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                          Text(
                            type.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class BasicInfoSectionWidget extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final bool isEnabled;

  const BasicInfoSectionWidget({
    super.key,
    required this.titleController,
    required this.descriptionController,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          TextFormField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: 'Book Title',
              hintText: 'Enter book title',
              prefixIcon: const Icon(Icons.book_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            enabled: isEnabled,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          TextFormField(
            controller: descriptionController,
            decoration: InputDecoration(
              labelText: 'Book Description',
              hintText: 'Enter book description',
              prefixIcon: const Icon(Icons.description_rounded),
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            enabled: isEnabled,
            maxLines: 4,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class BookDetailsSectionWidget extends StatelessWidget {
  final TextEditingController durationController;
  final TextEditingController countryController;
  final TextEditingController categoryController;
  final TextEditingController? chaptersController;
  final BookLevel selectedLevel;
  final CourseCategory selectedCategory;
  final Function(BookLevel) onLevelChanged;
  final Function(CourseCategory) onCategoryChanged;
  final BookUploadType uploadType;
  final int chaptersCount;
  final bool isEnabled;

  const BookDetailsSectionWidget({
    super.key,
    required this.durationController,
    required this.countryController,
    required this.categoryController,
    this.chaptersController,
    required this.selectedLevel,
    required this.selectedCategory,
    required this.onLevelChanged,
    required this.onCategoryChanged,
    required this.uploadType,
    this.chaptersCount = 0,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Book Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: durationController,
                  decoration: InputDecoration(
                    labelText: 'Duration',
                    hintText: '30 mins',
                    prefixIcon: const Icon(Icons.timer_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  enabled: isEnabled,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.03),
              if (uploadType == BookUploadType.singlePdf && chaptersController != null)
                Expanded(
                  child: TextFormField(
                    controller: chaptersController,
                    decoration: InputDecoration(
                      labelText: 'Chapters',
                      hintText: '1',
                      prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    enabled: isEnabled,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Numbers only';
                      }
                      return null;
                    },
                  ),
                )
              else
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.04,
                      vertical: MediaQuery.of(context).size.height * 0.02,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surface,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.format_list_numbered_rounded,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                        Expanded(
                          child: Text(
                            'Chapters: $chaptersCount',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: countryController,
                  decoration: InputDecoration(
                    labelText: 'Country',
                    hintText: 'Korea',
                    prefixIcon: const Icon(Icons.public_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  enabled: isEnabled,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.03),
              Expanded(
                child: TextFormField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    hintText: 'Language',
                    prefixIcon: const Icon(Icons.category_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  enabled: isEnabled,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          DropdownButtonFormField<BookLevel>(
            value: selectedLevel,
            decoration: InputDecoration(
              labelText: 'Level',
              prefixIcon: const Icon(Icons.bar_chart_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            isDense: true,
            items: BookLevel.values.map((level) {
              return DropdownMenuItem<BookLevel>(
                value: level,
                child: Text(
                  level.toString().split('.').last,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: isEnabled ? (BookLevel? newValue) {
              if (newValue != null) {
                onLevelChanged(newValue);
              }
            } : null,
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          DropdownButtonFormField<CourseCategory>(
            value: selectedCategory,
            decoration: InputDecoration(
              labelText: 'Course Category',
              prefixIcon: const Icon(Icons.school_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            isDense: true,
            items: CourseCategory.values.map((category) {
              if (category == CourseCategory.favorite) {
                return null;
              }
              return DropdownMenuItem<CourseCategory>(
                value: category,
                child: Text(
                  category.toString().split('.').last,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).where((item) => item != null).cast<DropdownMenuItem<CourseCategory>>().toList(),
            onChanged: isEnabled ? (CourseCategory? newValue) {
              if (newValue != null) {
                onCategoryChanged(newValue);
              }
            } : null,
          ),
        ],
      ),
    );
  }
}

class SinglePdfSectionWidget extends StatelessWidget {
  final File? selectedPdfFile;
  final String? pdfFileName;
  final bool pdfSelected;
  final VoidCallback onPickPdf;
  final bool isEnabled;
  final bool isEdit;
  final BookItem? existingBook;

  const SinglePdfSectionWidget({
    super.key,
    this.selectedPdfFile,
    this.pdfFileName,
    this.pdfSelected = false,
    required this.onPickPdf,
    this.isEnabled = true,
    this.isEdit = false,
    this.existingBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                color: theme.colorScheme.primary,
                size: MediaQuery.of(context).size.width * 0.06,
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              Text(
                isEdit ? 'Update PDF File' : 'Book PDF File',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.02,
                  vertical: MediaQuery.of(context).size.height * 0.005,
                ),
                decoration: BoxDecoration(
                  color: isEdit 
                      ? theme.colorScheme.secondary.withValues(alpha: 0.1)
                      : theme.colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isEdit ? 'Optional' : 'Required',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isEdit ? theme.colorScheme.secondary : theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          
          BlocBuilder<FileUploadCubit, FileUploadState>(
            builder: (context, fileState) {
              bool isPdfPickerLoading = fileState is FilePickerLoading &&
                  fileState.fileType == FileUploadType.pdf;

              return Container(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: pdfSelected 
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: pdfSelected 
                      ? theme.colorScheme.primary.withValues(alpha: 0.05)
                      : theme.colorScheme.surface,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
                          decoration: BoxDecoration(
                            color: pdfSelected 
                                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                : theme.colorScheme.outline.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            pdfSelected ? Icons.check_circle_rounded : Icons.picture_as_pdf_rounded,
                            color: pdfSelected 
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            size: MediaQuery.of(context).size.width * 0.05,
                          ),
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pdfFileName ?? 
                                (isEdit && existingBook?.pdfUrl != null 
                                    ? 'Current PDF: ${existingBook!.id}.pdf' 
                                    : 'No PDF selected'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: pdfSelected 
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontWeight: pdfSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (pdfSelected)
                                Text(
                                  isEdit ? 'New PDF file ready for upload' : 'PDF file ready for upload',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                  ),
                                )
                              else if (isEdit && existingBook?.pdfUrl != null)
                                Text(
                                  'Keep current PDF or select new one',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (fileState is FilePickerError && fileState.fileType == FileUploadType.pdf) ...[
                      SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                      Container(
                        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: theme.colorScheme.error,
                              size: MediaQuery.of(context).size.width * 0.04,
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                            Expanded(
                              child: Text(
                                fileState.message,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (isEnabled && !isPdfPickerLoading) ? onPickPdf : null,
                        icon: isPdfPickerLoading
                            ? SizedBox(
                                width: MediaQuery.of(context).size.width * 0.04,
                                height: MediaQuery.of(context).size.width * 0.04,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: Text(isPdfPickerLoading ? 'Selecting...' : 
                                    isEdit ? 'Select New PDF File' : 'Select PDF File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(
                            vertical: MediaQuery.of(context).size.height * 0.015,
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
              );
            },
          ),
        ],
      ),
    );
  }
}

class CoverImageSectionWidget extends StatelessWidget {
  final File? selectedImageFile;
  final String? imageFileName;
  final bool imageSelected;
  final VoidCallback onPickImage;
  final bool isEnabled;
  final bool isEdit;
  final BookItem? existingBook;

  const CoverImageSectionWidget({
    super.key,
    this.selectedImageFile,
    this.imageFileName,
    this.imageSelected = false,
    required this.onPickImage,
    this.isEnabled = true,
    this.isEdit = false,
    this.existingBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.image_rounded,
                color: theme.colorScheme.secondary,
                size: MediaQuery.of(context).size.width * 0.06,
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              Text(
                isEdit ? 'Update Cover Image' : 'Cover Image',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.02,
                  vertical: MediaQuery.of(context).size.height * 0.005,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Optional',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          
          BlocBuilder<FileUploadCubit, FileUploadState>(
            builder: (context, fileState) {
              bool isImagePickerLoading = fileState is FilePickerLoading &&
                  fileState.fileType == FileUploadType.image;

              return Container(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: imageSelected 
                        ? theme.colorScheme.secondary.withValues(alpha: 0.5)
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: imageSelected 
                      ? theme.colorScheme.secondary.withValues(alpha: 0.05)
                      : theme.colorScheme.surface,
                ),
                child: Column(
                  children: [
                    if (selectedImageFile != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          selectedImageFile!,
                          height: MediaQuery.of(context).size.height * 0.2,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    ] else if (isEdit && existingBook?.bookImage != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: existingBook!.bookImage!,
                          height: MediaQuery.of(context).size.height * 0.2,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: MediaQuery.of(context).size.height * 0.2,
                            color: theme.colorScheme.outline.withValues(alpha: 0.1),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: MediaQuery.of(context).size.height * 0.2,
                            color: theme.colorScheme.outline.withValues(alpha: 0.1),
                            child: Center(
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                size: MediaQuery.of(context).size.width * 0.12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    ],
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
                          decoration: BoxDecoration(
                            color: imageSelected 
                                ? theme.colorScheme.secondary.withValues(alpha: 0.1)
                                : theme.colorScheme.outline.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            imageSelected ? Icons.check_circle_rounded : Icons.image_rounded,
                            color: imageSelected 
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            size: MediaQuery.of(context).size.width * 0.05,
                          ),
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                imageFileName ?? 
                                (isEdit && existingBook?.bookImage != null 
                                    ? 'Current cover image' 
                                    : 'No image selected'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: imageSelected 
                                      ? theme.colorScheme.secondary
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontWeight: imageSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (imageSelected)
                                Text(
                                  isEdit ? 'New image ready for upload' : 'Image ready for upload',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.secondary.withValues(alpha: 0.8),
                                  ),
                                )
                              else if (isEdit && existingBook?.bookImage != null)
                                Text(
                                  'Keep current image or select new one',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (fileState is FilePickerError && fileState.fileType == FileUploadType.image) ...[
                      SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                      Container(
                        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: theme.colorScheme.error,
                              size: MediaQuery.of(context).size.width * 0.04,
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                            Expanded(
                              child: Text(
                                fileState.message,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (isEnabled && !isImagePickerLoading) ? onPickImage : null,
                        icon: isImagePickerLoading
                            ? SizedBox(
                                width: MediaQuery.of(context).size.width * 0.04,
                                height: MediaQuery.of(context).size.width * 0.04,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onSecondary,
                                ),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: Text(isImagePickerLoading ? 'Selecting...' : 
                                    isEdit ? 'Select New Cover Image' : 'Select Cover Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: theme.colorScheme.onSecondary,
                          padding: EdgeInsets.symmetric(
                            vertical: MediaQuery.of(context).size.height * 0.015,
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
              );
            },
          ),
        ],
      ),
    );
  }
}

class AudioSectionWidget extends StatelessWidget {
  final List<AudioTrackUploadData> audioTracks;
  final Function(List<AudioTrackUploadData>) onAudioTracksChanged;
  final bool isEnabled;
  final bool isEdit;
  final List<AudioTrack>? existingAudioTracks;
  final bool audioTracksChanged;
  final VoidCallback? onEditExistingAudio;

  const AudioSectionWidget({
    super.key,
    required this.audioTracks,
    required this.onAudioTracksChanged,
    this.isEnabled = true,
    this.isEdit = false,
    this.existingAudioTracks,
    this.audioTracksChanged = false,
    this.onEditExistingAudio,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (isEdit && existingAudioTracks != null && existingAudioTracks!.isNotEmpty && !audioTracksChanged) ...[
          MultiAudioPlayerWidget(
            audioTracks: existingAudioTracks!,
            label: 'Current Audio Tracks (${existingAudioTracks!.length})',
            onEdit: onEditExistingAudio,
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        ],
        if (!isEdit || audioTracksChanged || (existingAudioTracks?.isEmpty ?? true))
          MultiAudioTrackManagerWidget(
            audioTracks: audioTracks,
            onAudioTracksChanged: onAudioTracksChanged,
            label: isEdit ? 'Update Audio Tracks' : 'Book Audio Tracks',
          ),
      ],
    );
  }
}

class ProgressSectionWidget extends StatelessWidget {
  final double progress;
  final bool isUpdate;

  const ProgressSectionWidget({
    super.key,
    required this.progress,
    this.isUpdate = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_upload_rounded,
                color: colorScheme.primary,
                size: MediaQuery.of(context).size.width * 0.05,
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              Text(
                '${isUpdate ? 'Updating' : 'Uploading'} ${(progress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              minHeight: MediaQuery.of(context).size.height * 0.008,
            ),
          ),
        ],
      ),
    );
  }
}

class BottomActionButtonWidget extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final String label;
  final String loadingLabel;
  final IconData icon;
  final IconData loadingIcon;

  const BottomActionButtonWidget({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    required this.label,
    required this.loadingLabel,
    required this.icon,
    required this.loadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.06,
          child: ElevatedButton.icon(
            onPressed: (isLoading || !isEnabled) ? null : onPressed,
            icon: Icon(
              isLoading ? loadingIcon : icon,
              size: MediaQuery.of(context).size.width * 0.05,
            ),
            label: Text(
              isLoading ? loadingLabel : label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isEnabled ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.3),
              foregroundColor: isEnabled ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}