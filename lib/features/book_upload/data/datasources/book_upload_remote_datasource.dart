import 'dart:io';

import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

abstract class BookUploadRemoteDataSource {
  Future<BookItem> uploadBook(BookItem book, File pdfFile, {File? coverImageFile, List<AudioTrackUploadData>? audioTracks});
  
  Future<BookItem> uploadBookWithChapters(
    BookItem book, 
    List<ChapterUploadData> chapters, 
    {File? coverImageFile}
  );
  
  Future<BookItem> updateBook(String bookId, BookItem updatedBook, {File? pdfFile, File? coverImageFile, List<AudioTrackUploadData>? audioTracks});
  
  Future<BookItem> updateBookWithChapters(
    String bookId, 
    BookItem updatedBook, 
    List<ChapterUploadData>? chapters, 
    {File? coverImageFile}
  );
  
  Future<bool> deleteBook(String bookId);
  
  Future<List<BookItem>> searchBookById(String bookId);
  Future<BookItem?> getBookById(String bookId);
}