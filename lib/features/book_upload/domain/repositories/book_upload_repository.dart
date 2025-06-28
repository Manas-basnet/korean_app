import 'dart:io';

import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/shared/models/book_item.dart';

abstract class BookUploadRepository {
  Future<ApiResult<BookItem>> createBook(BookItem book, File pdfFile, {File? coverImageFile, File? audioFile});
  
  Future<ApiResult<BookItem>> createBookWithChapters(
    BookItem book, 
    List<ChapterUploadData> chapters, 
    {File? coverImageFile}
  );
  
  Future<ApiResult<BookItem>> updateBook(String bookId, BookItem updatedBook, {File? pdfFile, File? coverImageFile, File? audioFile});
  
  Future<ApiResult<BookItem>> updateBookWithChapters(
    String bookId, 
    BookItem updatedBook, 
    List<ChapterUploadData>? chapters, 
    {File? coverImageFile}
  );
  
  Future<ApiResult<bool>> deleteBook(String bookId);
  
  Future<ApiResult<bool>> hasEditPermission(String bookId, String userId);
  Future<ApiResult<bool>> hasDeletePermission(String bookId, String userId);
}