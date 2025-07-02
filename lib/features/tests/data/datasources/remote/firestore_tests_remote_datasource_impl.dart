import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/tests/data/datasources/remote/tests_remote_datasource.dart';
import 'package:korean_language_app/features/tests/domain/entities/user_test_interation.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/models/test_related/test_item.dart';

class FirestoreTestsDataSourceImpl implements TestsRemoteDataSource {
  
  FirestoreTestsDataSourceImpl({
    required this.firestore,
  });

  final FirebaseFirestore firestore;
  final String testsCollection = 'tests';
  final Map<String, DocumentSnapshot?> _lastDocuments = {};

  @override
  Future<List<TestItem>> getTests({
    int page = 0,
    int pageSize = 5,
    TestSortType sortType = TestSortType.recent,
  }) async {
    try {
      final cacheKey = 'tests_${sortType.name}';
      
      if (page == 0) {
        _lastDocuments[cacheKey] = null;
      }

      Query query = firestore.collection(testsCollection)
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
        return TestItem.fromJson(data);
      }).toList();
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to fetch tests: $e');
    }
  }

  @override
  Future<List<TestItem>> getTestsByCategory(
    TestCategory category, {
    int page = 0,
    int pageSize = 5,
    TestSortType sortType = TestSortType.recent,
  }) async {
    try {
      final cacheKey = 'category_${category.name}_${sortType.name}';
      
      if (page == 0) {
        _lastDocuments[cacheKey] = null;
      }

      Query query = firestore.collection(testsCollection)
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
        return TestItem.fromJson(data);
      }).toList();
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to fetch tests by category: $e');
    }
  }

  @override
  Future<bool> hasMoreTests(int currentCount, [TestSortType? sortType]) async {
    try {
      final countQuery = await firestore.collection(testsCollection)
          .where('isPublished', isEqualTo: true)
          .count()
          .get();
      
      return currentCount < countQuery.count!;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to check for more tests: $e');
    }
  }

  @override
  Future<bool> hasMoreTestsByCategory(TestCategory category, int currentCount, [TestSortType? sortType]) async {
    try {
      final countQuery = await firestore.collection(testsCollection)
          .where('isPublished', isEqualTo: true)
          .where('category', isEqualTo: category.toString().split('.').last)
          .count()
          .get();
      
      return currentCount < countQuery.count!;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to check for more tests by category: $e');
    }
  }

  @override
  Future<List<TestItem>> searchTests(String query) async {
    try {
      final normalizedQuery = query.toLowerCase();
      
      final titleQuery = firestore.collection(testsCollection)
          .where('isPublished', isEqualTo: true)
          .where('titleLowerCase', isGreaterThanOrEqualTo: normalizedQuery)
          .where('titleLowerCase', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
          .limit(10);
      
      final titleSnapshot = await titleQuery.get();
      final List<TestItem> results = titleSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TestItem.fromJson(data);
      }).toList();
      
      if (results.length < 5) {
        final descQuery = firestore.collection(testsCollection)
            .where('isPublished', isEqualTo: true)
            .where('descriptionLowerCase', isGreaterThanOrEqualTo: normalizedQuery)
            .where('descriptionLowerCase', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
            .limit(10);
            
        final descSnapshot = await descQuery.get();
        final descResults = descSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return TestItem.fromJson(data);
        }).toList();
        
        for (final test in descResults) {
          if (!results.any((t) => t.id == test.id)) {
            results.add(test);
          }
        }
      }
      
      return results;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to search tests: $e');
    }
  }

  @override
  Future<TestItem?> getTestById(String testId) async {
    try {
      final docSnapshot = await firestore.collection(testsCollection).doc(testId).get();
      
      if (!docSnapshot.exists) {
        return null;
      }
      
      final data = docSnapshot.data() as Map<String, dynamic>;
      data['id'] = docSnapshot.id;
      
      return TestItem.fromJson(data);
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to get test by ID: $e');
    }
  }

  @override
  Future<void> recordTestView(String testId, String userId) async {
    return;
  }

  @override
  Future<void> rateTest(String testId, String userId, double rating) async {
    return;
  }

  @override
  Future<UserTestInteraction?> completeTestWithViewAndRating(
    String testId, 
    String userId, 
    double? rating,
    UserTestInteraction? userInteration
  ) async {
    try {
      final batch = firestore.batch();
      
      
      final testRef = firestore.collection(testsCollection).doc(testId);
      final interactionRef = firestore
          .collection(testsCollection)
          .doc(testId)
          .collection('user_interactions')
          .doc(userId);
      
      final testDoc = await testRef.get();
      
      if (!testDoc.exists) {
        throw Exception('Test not found');
      }
      
      final testData = testDoc.data() as Map<String, dynamic>;
      final testItem = TestItem.fromJson(testData);
      final existingInteraction = userInteration;
      
      // Check if we should update view count (5-minute cooldown)
      bool shouldUpdateViewCount = true;
      if (existingInteraction != null && userInteration?.viewedAt != null) {
        final lastViewed = existingInteraction.viewedAt;
        final now = DateTime.now();
        final timeDifference = now.difference(lastViewed!).inMinutes;
        shouldUpdateViewCount = timeDifference >= 5;
      }
      
      // Prepare interaction data
      var interactionData = UserTestInteraction(
        userId: userId, 
        testId: testId,
        completionCount: (existingInteraction?.completionCount ?? 0) + 1
      );
      
      // Handle view count update
      if (shouldUpdateViewCount) {
        interactionData = interactionData.copyWith(hasViewed: true);
        interactionData = interactionData.copyWith(viewedAt: DateTime.now());
        
        // Only increment view count if we're updating the view
        batch.update(testRef, {
          'viewCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Keep existing view data
        interactionData = interactionData.copyWith(hasViewed: existingInteraction?.hasViewed ?? false);
        interactionData = interactionData.copyWith(viewedAt: existingInteraction?.viewedAt ?? DateTime.now());
      }
      
      // Handle rating update if provided
      if (rating != null) {
        final currentRating = testItem.rating;
        final currentRatingCount = testItem.ratingCount;
        final previousRating = existingInteraction?.rating;
        final hasRated = existingInteraction?.hasRated ?? false;
        
        double newRating;
        int newRatingCount;
        
        if (hasRated && previousRating != null) {
          // Update existing rating
          final totalRating = currentRating * currentRatingCount;
          final adjustedTotal = totalRating - previousRating + rating;
          newRating = adjustedTotal / currentRatingCount;
          newRatingCount = currentRatingCount;
        } else {
          // Add new rating
          final totalRating = currentRating * currentRatingCount;
          newRating = (totalRating + rating) / (currentRatingCount + 1);
          newRatingCount = currentRatingCount + 1;
        }
        
        // Update interaction with rating
        interactionData = interactionData.copyWith(hasRated: true);
        interactionData = interactionData.copyWith(rating: rating);
        interactionData = interactionData.copyWith(ratedAt: DateTime.now());
        
        // Update test document with new rating (combine with view count update if needed)
        final testUpdateData = <String, dynamic>{
          'rating': newRating,
          'ratingCount': newRatingCount,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        if (shouldUpdateViewCount) {
          // Already added viewCount increment above, just merge the rating data
          batch.update(testRef, {
            ...testUpdateData,
            'viewCount': FieldValue.increment(1),
          });
        } else {
          // Only update rating data
          batch.update(testRef, testUpdateData);
        }
      } else {
        // Keep existing rating data
        interactionData = interactionData.copyWith(hasRated: existingInteraction?.hasRated ?? false);
        interactionData = interactionData.copyWith(rating: existingInteraction?.rating);
        interactionData = interactionData.copyWith(ratedAt: existingInteraction?.ratedAt);
      }

      final interationMap = interactionData.toJson();
      
      // Update user interaction
      batch.set(interactionRef, interationMap, SetOptions(merge: true));
      
      await batch.commit();
      
      await _updateTestPopularity(testId);

      return interactionData;
      
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to complete test with view and rating: $e');
    }
  }

  @override
  Future<UserTestInteraction?> getUserTestInteraction(String testId, String userId) async {
    try {
      final doc = await firestore
          .collection(testsCollection)
          .doc(testId)
          .collection('user_interactions')
          .doc(userId)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      final data = doc.data() as Map<String, dynamic>;
      return UserTestInteraction.fromJson(data);
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to get user test interaction: $e');
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

  Future<void> _updateTestPopularity(String testId) async {
    try {
      final testRef = firestore.collection(testsCollection).doc(testId);
      final testDoc = await testRef.get();
      
      if (!testDoc.exists) return;
      
      final data = testDoc.data() as Map<String, dynamic>;
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
      
      await testRef.update({
        'popularity': popularity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update test popularity: $e');
    }
  }
}