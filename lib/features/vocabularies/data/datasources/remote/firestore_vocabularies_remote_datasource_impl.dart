import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/vocabularies/data/datasources/remote/vocabularies_remote_datasource.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

class FirestoreVocabulariesDataSourceImpl implements VocabulariesRemoteDataSource {
  final FirebaseFirestore firestore;
  final String vocabulariesCollection = 'vocabularies';
  final Map<String, DocumentSnapshot?> _lastDocuments = {};

  FirestoreVocabulariesDataSourceImpl({
    required this.firestore,
  });

  @override
  Future<List<VocabularyItem>> getVocabularies({
    int page = 0,
    int pageSize = 5,
    BookLevel? level,
    SupportedLanguage? language,
  }) async {
    try {
      final cacheKey = 'vocabularies_${level?.name ?? 'all'}_${language?.name ?? 'all'}';
      
      if (page == 0) {
        _lastDocuments[cacheKey] = null;
      }

      Query query = firestore.collection(vocabulariesCollection)
          .where('isPublished', isEqualTo: true);

      if (level != null) {
        query = query.where('level', isEqualTo: level.toString().split('.').last);
      }
      
      if (language != null) {
        query = query.where('primaryLanguage', isEqualTo: language.toString().split('.').last);
      }

      query = query.orderBy('createdAt', descending: true);
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
        return VocabularyItem.fromJson(data);
      }).toList();
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to fetch vocabularies: $e');
    }
  }

  @override
  Future<List<VocabularyItem>> getVocabulariesByLevel(
    BookLevel level, {
    int page = 0,
    int pageSize = 5,
  }) async {
    try {
      final cacheKey = 'level_${level.name}';
      
      if (page == 0) {
        _lastDocuments[cacheKey] = null;
      }

      Query query = firestore.collection(vocabulariesCollection)
          .where('isPublished', isEqualTo: true)
          .where('level', isEqualTo: level.toString().split('.').last);

      query = query.orderBy('createdAt', descending: true);
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
        return VocabularyItem.fromJson(data);
      }).toList();
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to fetch vocabularies by level: $e');
    }
  }

  @override
  Future<List<VocabularyItem>> getVocabulariesByLanguage(
    SupportedLanguage language, {
    int page = 0,
    int pageSize = 5,
  }) async {
    try {
      final cacheKey = 'language_${language.name}';
      
      if (page == 0) {
        _lastDocuments[cacheKey] = null;
      }

      Query query = firestore.collection(vocabulariesCollection)
          .where('isPublished', isEqualTo: true)
          .where('primaryLanguage', isEqualTo: language.toString().split('.').last);

      query = query.orderBy('createdAt', descending: true);
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
        return VocabularyItem.fromJson(data);
      }).toList();
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to fetch vocabularies by language: $e');
    }
  }

  @override
  Future<bool> hasMoreVocabularies(int currentCount) async {
    try {
      final countQuery = await firestore.collection(vocabulariesCollection)
          .where('isPublished', isEqualTo: true)
          .count()
          .get();
      
      return currentCount < countQuery.count!;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to check for more vocabularies: $e');
    }
  }

  @override
  Future<bool> hasMoreVocabulariesByLevel(BookLevel level, int currentCount) async {
    try {
      final countQuery = await firestore.collection(vocabulariesCollection)
          .where('isPublished', isEqualTo: true)
          .where('level', isEqualTo: level.toString().split('.').last)
          .count()
          .get();
      
      return currentCount < countQuery.count!;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to check for more vocabularies by level: $e');
    }
  }

  @override
  Future<bool> hasMoreVocabulariesByLanguage(SupportedLanguage language, int currentCount) async {
    try {
      final countQuery = await firestore.collection(vocabulariesCollection)
          .where('isPublished', isEqualTo: true)
          .where('primaryLanguage', isEqualTo: language.toString().split('.').last)
          .count()
          .get();
      
      return currentCount < countQuery.count!;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to check for more vocabularies by language: $e');
    }
  }

  @override
  Future<List<VocabularyItem>> searchVocabularies(String query) async {
    try {
      final normalizedQuery = query.toLowerCase();
      
      final titleQuery = firestore.collection(vocabulariesCollection)
          .where('isPublished', isEqualTo: true)
          .where('titleLowerCase', isGreaterThanOrEqualTo: normalizedQuery)
          .where('titleLowerCase', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
          .limit(10);
      
      final titleSnapshot = await titleQuery.get();
      final List<VocabularyItem> results = titleSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return VocabularyItem.fromJson(data);
      }).toList();
      
      if (results.length < 5) {
        final descQuery = firestore.collection(vocabulariesCollection)
            .where('isPublished', isEqualTo: true)
            .where('descriptionLowerCase', isGreaterThanOrEqualTo: normalizedQuery)
            .where('descriptionLowerCase', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
            .limit(10);
            
        final descSnapshot = await descQuery.get();
        final descResults = descSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return VocabularyItem.fromJson(data);
        }).toList();
        
        for (final vocabulary in descResults) {
          if (!results.any((v) => v.id == vocabulary.id)) {
            results.add(vocabulary);
          }
        }
      }
      
      return results;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to search vocabularies: $e');
    }
  }

  @override
  Future<VocabularyItem?> getVocabularyById(String vocabularyId) async {
    try {
      final docSnapshot = await firestore.collection(vocabulariesCollection).doc(vocabularyId).get();
      
      if (!docSnapshot.exists) {
        return null;
      }
      
      final data = docSnapshot.data() as Map<String, dynamic>;
      data['id'] = docSnapshot.id;
      
      return VocabularyItem.fromJson(data);
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to get vocabulary by ID: $e');
    }
  }

  @override
  Future<void> recordVocabularyView(String vocabularyId, String userId) async {
    try {
      final vocabularyRef = firestore.collection(vocabulariesCollection).doc(vocabularyId);
      
      await vocabularyRef.update({
        'viewCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to record vocabulary view: $e');
    }
  }

  @override
  Future<void> rateVocabulary(String vocabularyId, String userId, double rating) async {
    try {
      final vocabularyRef = firestore.collection(vocabulariesCollection).doc(vocabularyId);
      final vocabularyDoc = await vocabularyRef.get();
      
      if (!vocabularyDoc.exists) {
        throw Exception('Vocabulary not found');
      }
      
      final vocabularyData = vocabularyDoc.data() as Map<String, dynamic>;
      final currentRating = (vocabularyData['rating'] as num?)?.toDouble() ?? 0.0;
      final currentRatingCount = vocabularyData['ratingCount'] as int? ?? 0;
      
      final totalRating = currentRating * currentRatingCount;
      final newRating = (totalRating + rating) / (currentRatingCount + 1);
      final newRatingCount = currentRatingCount + 1;
      
      await vocabularyRef.update({
        'rating': newRating,
        'ratingCount': newRatingCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to rate vocabulary: $e');
    }
  }
}