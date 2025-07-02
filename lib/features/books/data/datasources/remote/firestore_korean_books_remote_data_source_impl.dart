import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/shared/models/book_related/chapter.dart';
import 'package:korean_language_app/features/books/data/datasources/remote/korean_books_remote_data_source.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class FirestoreKoreanBooksDataSource implements KoreanBooksRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final String booksCollection = 'korean_books';
  
  DocumentSnapshot? _lastDocument;

  FirestoreKoreanBooksDataSource({
    required this.firestore,
    required this.storage,
  });

  @override
  Future<List<BookItem>> getKoreanBooks({int page = 0, int pageSize = 5}) async {
    try {
      if (page == 0) {
        _lastDocument = null;
      }

      Query query = firestore.collection(booksCollection)
          .orderBy('title')
          .limit(pageSize);
      
      if (page > 0 && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      
      final querySnapshot = await query.get();
      final docs = querySnapshot.docs;
      
      if (docs.isNotEmpty) {
        _lastDocument = docs.last;
      }
      
      return docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; 
        return BookItem.fromJson(data);
      }).toList();
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to fetch books: $e');
    }
  }

  @override
  Future<bool> hasMoreBooks(int currentCount) async {
    try {
      final countQuery = await firestore.collection(booksCollection).count().get();
      return currentCount < countQuery.count!;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to check for more books: $e');
    }
  }

  @override
  Future<List<BookItem>> searchKoreanBooks(String query) async {
    try {
      final normalizedQuery = query.toLowerCase();
      
      final titleQuery = firestore.collection(booksCollection)
          .where('titleLowerCase', isGreaterThanOrEqualTo: normalizedQuery)
          .where('titleLowerCase', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
          .limit(10);
      
      final titleSnapshot = await titleQuery.get();
      final List<BookItem> results = titleSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return BookItem.fromJson(data);
      }).toList();
      
      if (results.length < 5) {
        final descQuery = firestore.collection(booksCollection)
            .where('descriptionLowerCase', isGreaterThanOrEqualTo: normalizedQuery)
            .where('descriptionLowerCase', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
            .limit(10);
            
        final descSnapshot = await descQuery.get();
        final descResults = descSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return BookItem.fromJson(data);
        }).toList();
        
        for (final book in descResults) {
          if (!results.any((b) => b.id == book.id)) {
            results.add(book);
          }
        }
      }
      
      return results;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to search books: $e');
    }
  }

  @override
  Future<bool> updateBook(String bookId, BookItem updatedBook) async {
    try {
      final docRef = firestore.collection(booksCollection).doc(bookId);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        throw Exception('Book not found');
      }
      
      final updateData = updatedBook.toJson();
      
      updateData['titleLowerCase'] = updatedBook.title.toLowerCase();
      updateData['descriptionLowerCase'] = updatedBook.description.toLowerCase();
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      
      await docRef.update(updateData);
      
      return true;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to update book: $e');
    }
  }
  
  @override
  Future<File?> downloadPdfToLocal(String bookId, String localPath) async {
    try {
      final pdfUrl = await getPdfDownloadUrl(bookId);
      
      if (pdfUrl == null || pdfUrl.isEmpty) {
        return null;
      }
      
      final ref = storage.refFromURL(pdfUrl);
      final file = File(localPath);
      
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      final downloadTask = ref.writeToFile(file);
      await downloadTask;
      
      if (await file.exists() && await file.length() > 0) {
        return file;
      } else {
        return null;
      }
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to download PDF: $e');
    }
  }

  @override
  Future<String?> getPdfDownloadUrl(String bookId) async {
    try {
      final docSnapshot = await firestore.collection(booksCollection).doc(bookId).get();
      
      if (!docSnapshot.exists) {
        return null;
      }
      
      final data = docSnapshot.data() as Map<String, dynamic>;
      
      if (data.containsKey('pdfUrl') && data['pdfUrl'] != null) {
        return data['pdfUrl'] as String;
      }
      
      return null;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to get PDF URL: $e');
    }
  }

  @override
  Future<File?> downloadChapterPdfToLocal(String bookId, String chapterId, String localPath) async {
    try {
      final chapterPdfUrl = await getChapterPdfDownloadUrl(bookId, chapterId);
      
      if (chapterPdfUrl == null || chapterPdfUrl.isEmpty) {
        return null;
      }
      
      final ref = storage.refFromURL(chapterPdfUrl);
      final file = File(localPath);
      
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      final downloadTask = ref.writeToFile(file);
      await downloadTask;
      
      if (await file.exists() && await file.length() > 0) {
        return file;
      } else {
        return null;
      }
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to download chapter PDF: $e');
    }
  }

  @override
  Future<String?> getChapterPdfDownloadUrl(String bookId, String chapterId) async {
    try {
      final docSnapshot = await firestore.collection(booksCollection).doc(bookId).get();
      
      if (!docSnapshot.exists) {
        return null;
      }
      
      final data = docSnapshot.data() as Map<String, dynamic>;
      
      if (data.containsKey('chapters') && data['chapters'] is List) {
        final chapters = (data['chapters'] as List)
            .map((chapterJson) => Chapter.fromJson(chapterJson))
            .toList();
        
        final chapter = chapters.firstWhere(
          (c) => c.id == chapterId,
          orElse: () => const Chapter(
            id: '',
            title: '',
            order: 0,
          ),
        );
        
        if (chapter.id.isNotEmpty && chapter.pdfUrl != null) {
          return chapter.pdfUrl;
        }
      }
      
      return null;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to get chapter PDF URL: $e');
    }
  }

  @override
  Future<String?> regenerateUrlFromPath(String storagePath) async {
    try {
      if (storagePath.isEmpty) {
        return null;
      }
      
      final fileRef = storage.ref().child(storagePath);
      final downloadUrl = await fileRef.getDownloadURL();
      
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to regenerate URL: $e');
    }
  }
}