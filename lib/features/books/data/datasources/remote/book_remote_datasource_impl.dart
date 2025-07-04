import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/books/data/datasources/remote/book_remote_datasource.dart';
import 'package:korean_language_app/features/books/domain/entities/user_book_interaction.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class FirestoreBooksDataSourceImpl implements BooksRemoteDataSource {
  
  FirestoreBooksDataSourceImpl({
    required this.firestore,
  });

  final FirebaseFirestore firestore;
  final String booksCollection = 'books';
  final Map<String, DocumentSnapshot?> _lastDocuments = {};

  @override
  Future<List<BookItem>> getBooks({
    int page = 0,
    int pageSize = 5,
    TestSortType sortType = TestSortType.recent,
  }) async {
    try {
      final cacheKey = 'books_${sortType.name}';
      
      if (page == 0) {
        _lastDocuments[cacheKey] = null;
      }

      Query query = firestore.collection(booksCollection)
          .where('isPublished', isEqualTo: true);

      query = _applySorting(query, sortType);
      query = query.limit(pageSize);
      
      if (page > 0 && _lastDocuments[cacheKey] != null) {
        query = query.startAfterDocument(_lastDocuments[cacheKey]!);
      }
      
      final querySnapshot = await query.get();
      final docs = querySnapshot.docs;
      
      if (docs.isNotEmpty) {
        _lastDocuments[cacheKey] = docs.last;
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
  Future<List<BookItem>> getBooksByCategory(
    CourseCategory category, {
    int page = 0,
    int pageSize = 5,
    TestSortType sortType = TestSortType.recent,
  }) async {
    try {
      final cacheKey = 'category_${category.name}_${sortType.name}';
      
      if (page == 0) {
        _lastDocuments[cacheKey] = null;
      }

      Query query = firestore.collection(booksCollection)
          .where('isPublished', isEqualTo: true)
          .where('category', isEqualTo: category.toString().split('.').last);

      query = _applySorting(query, sortType);
      query = query.limit(pageSize);
      
      if (page > 0 && _lastDocuments[cacheKey] != null) {
        query = query.startAfterDocument(_lastDocuments[cacheKey]!);
      }
      
      final querySnapshot = await query.get();
      final docs = querySnapshot.docs;
      
      if (docs.isNotEmpty) {
        _lastDocuments[cacheKey] = docs.last;
      }
      
      return docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; 
        return BookItem.fromJson(data);
      }).toList();
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to fetch books by category: $e');
    }
  }

  @override
  Future<bool> hasMoreBooks(int currentCount, [TestSortType? sortType]) async {
    try {
      final countQuery = await firestore.collection(booksCollection)
          .where('isPublished', isEqualTo: true)
          .count()
          .get();
      
      return currentCount < countQuery.count!;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to check for more books: $e');
    }
  }

  @override
  Future<bool> hasMoreBooksByCategory(CourseCategory category, int currentCount, [TestSortType? sortType]) async {
    try {
      final countQuery = await firestore.collection(booksCollection)
          .where('isPublished', isEqualTo: true)
          .where('category', isEqualTo: category.toString().split('.').last)
          .count()
          .get();
      
      return currentCount < countQuery.count!;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to check for more books by category: $e');
    }
  }

  @override
  Future<List<BookItem>> searchBooks(String query) async {
    try {
      final normalizedQuery = query.toLowerCase();
      
      final titleQuery = firestore.collection(booksCollection)
          .where('isPublished', isEqualTo: true)
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
            .where('isPublished', isEqualTo: true)
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
  Future<BookItem?> getBookById(String bookId) async {
    try {
      final docSnapshot = await firestore.collection(booksCollection).doc(bookId).get();
      
      if (!docSnapshot.exists) {
        return null;
      }
      
      final data = docSnapshot.data() as Map<String, dynamic>;
      data['id'] = docSnapshot.id;
      
      return BookItem.fromJson(data);
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to get book by ID: $e');
    }
  }

  @override
  Future<void> recordBookView(String bookId, String userId) async {
    return;
  }

  @override
  Future<void> rateBook(String bookId, String userId, double rating) async {
    return;
  }

  @override
  Future<UserBookInteraction?> completeBookWithViewAndRating(
    String bookId, 
    String userId, 
    double? rating,
    UserBookInteraction? userInteraction
  ) async {
    try {
      final batch = firestore.batch();
      
      final bookRef = firestore.collection(booksCollection).doc(bookId);
      final interactionRef = firestore
          .collection(booksCollection)
          .doc(bookId)
          .collection('user_interactions')
          .doc(userId);
      
      final bookDoc = await bookRef.get();
      
      if (!bookDoc.exists) {
        throw Exception('Book not found');
      }
      
      final bookData = bookDoc.data() as Map<String, dynamic>;
      final bookItem = BookItem.fromJson(bookData);
      final existingInteraction = userInteraction;
      
      // Check if we should update view count (5-minute cooldown)
      bool shouldUpdateViewCount = true;
      if (existingInteraction != null && userInteraction?.viewedAt != null) {
        final lastViewed = existingInteraction.viewedAt;
        final now = DateTime.now();
        final timeDifference = now.difference(lastViewed!).inMinutes;
        shouldUpdateViewCount = timeDifference >= 5;
      }
      
      // Prepare interaction data
      var interactionData = UserBookInteraction(
        userId: userId, 
        bookId: bookId,
        readingCount: (existingInteraction?.readingCount ?? 0) + 1
      );
      
      // Handle view count update
      if (shouldUpdateViewCount) {
        interactionData = interactionData.copyWith(hasViewed: true);
        interactionData = interactionData.copyWith(viewedAt: DateTime.now());
        
        batch.update(bookRef, {
          'viewCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        interactionData = interactionData.copyWith(hasViewed: existingInteraction?.hasViewed ?? false);
        interactionData = interactionData.copyWith(viewedAt: existingInteraction?.viewedAt ?? DateTime.now());
      }
      
      // Handle rating update if provided
      if (rating != null) {
        final currentRating = bookItem.rating;
        final currentRatingCount = bookItem.ratingCount;
        final previousRating = existingInteraction?.rating;
        final hasRated = existingInteraction?.hasRated ?? false;
        
        double newRating;
        int newRatingCount;
        
        if (hasRated && previousRating != null) {
          final totalRating = currentRating * currentRatingCount;
          final adjustedTotal = totalRating - previousRating + rating;
          newRating = adjustedTotal / currentRatingCount;
          newRatingCount = currentRatingCount;
        } else {
          final totalRating = currentRating * currentRatingCount;
          newRating = (totalRating + rating) / (currentRatingCount + 1);
          newRatingCount = currentRatingCount + 1;
        }
        
        interactionData = interactionData.copyWith(hasRated: true);
        interactionData = interactionData.copyWith(rating: rating);
        interactionData = interactionData.copyWith(ratedAt: DateTime.now());
        
        final bookUpdateData = <String, dynamic>{
          'rating': newRating,
          'ratingCount': newRatingCount,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        if (shouldUpdateViewCount) {
          batch.update(bookRef, {
            ...bookUpdateData,
            'viewCount': FieldValue.increment(1),
          });
        } else {
          batch.update(bookRef, bookUpdateData);
        }
      } else {
        interactionData = interactionData.copyWith(hasRated: existingInteraction?.hasRated ?? false);
        interactionData = interactionData.copyWith(rating: existingInteraction?.rating);
        interactionData = interactionData.copyWith(ratedAt: existingInteraction?.ratedAt);
      }

      // Preserve reading progress and other fields
      interactionData = interactionData.copyWith(
        readingProgress: existingInteraction?.readingProgress ?? 0.0,
        lastChapterId: existingInteraction?.lastChapterId,
        lastReadAt: existingInteraction?.lastReadAt,
      );

      final interactionMap = interactionData.toJson();
      
      batch.set(interactionRef, interactionMap, SetOptions(merge: true));
      
      await batch.commit();
      
      await _updateBookPopularity(bookId);

      return interactionData;
      
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to complete book with view and rating: $e');
    }
  }

  @override
  Future<UserBookInteraction?> getUserBookInteraction(String bookId, String userId) async {
    try {
      final doc = await firestore
          .collection(booksCollection)
          .doc(bookId)
          .collection('user_interactions')
          .doc(userId)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      final data = doc.data() as Map<String, dynamic>;
      return UserBookInteraction.fromJson(data);
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to get user book interaction: $e');
    }
  }

  Query _applySorting(Query query, TestSortType sortType) {
    switch (sortType) {
      case TestSortType.recent:
        return query.orderBy('createdAt', descending: true);
      case TestSortType.popular:
        return query.orderBy('popularity', descending: true);
      case TestSortType.rating:
        return query.orderBy('rating', descending: true);
      case TestSortType.viewCount:
        return query.orderBy('viewCount', descending: true);
    }
  }

  Future<void> _updateBookPopularity(String bookId) async {
    try {
      final bookRef = firestore.collection(booksCollection).doc(bookId);
      final bookDoc = await bookRef.get();
      
      if (!bookDoc.exists) return;
      
      final data = bookDoc.data() as Map<String, dynamic>;
      final viewCount = data['viewCount'] as int? ?? 0;
      final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
      final ratingCount = data['ratingCount'] as int? ?? 0;
      final createdAt = data['createdAt'] as Timestamp?;
      
      final daysSinceCreation = createdAt != null 
          ? DateTime.now().difference(createdAt.toDate()).inDays 
          : 0;
      
      final recencyBonus = daysSinceCreation < 30 ? (30 - daysSinceCreation) * 0.5 : 0;
      
      final popularity = (viewCount * 0.3) + 
                        (rating * 20 * 0.4) + 
                        (ratingCount * 0.2) + 
                        recencyBonus;
      
      await bookRef.update({
        'popularity': popularity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update book popularity: $e');
    }
  }
}