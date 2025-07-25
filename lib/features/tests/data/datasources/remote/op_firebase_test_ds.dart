// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:korean_language_app/core/utils/exception_mapper.dart';
// import 'package:korean_language_app/features/tests/data/datasources/remote/tests_remote_datasource.dart';
// import 'package:korean_language_app/features/tests/domain/entities/user_test_interation.dart';
// import 'package:korean_language_app/shared/enums/test_category.dart';
// import 'package:korean_language_app/shared/enums/test_sort_type.dart';
// import 'package:korean_language_app/shared/models/test_item.dart';

// class OptimizedFirestoreTestsDataSource implements TestsRemoteDataSource {
//   final FirebaseFirestore firestore;
//   final String testsCollection = 'tests';
//   final String interactionsSubcollection = 'interactions';
  
//   final Map<String, DocumentSnapshot?> _lastDocuments = {};

//   OptimizedFirestoreTestsDataSource({
//     required this.firestore,
//   });

//   @override
//   Future<List<TestItem>> getTests({
//     int page = 0,
//     int pageSize = 5,
//     TestSortType sortType = TestSortType.recent,
//   }) async {
//     try {
//       final cacheKey = 'tests_${sortType.name}';
      
//       if (page == 0) {
//         _lastDocuments[cacheKey] = null;
//       }

//       Query query = firestore.collection(testsCollection)
//           .where('isPublished', isEqualTo: true);

//       query = _applySorting(query, sortType);
//       query = query.limit(pageSize);
      
//       if (page > 0 && _lastDocuments[cacheKey] != null) {
//         query = query.startAfterDocument(_lastDocuments[cacheKey]!);
//       }
      
//       final querySnapshot = await query.get();
//       final docs = querySnapshot.docs;
      
//       if (docs.isNotEmpty) {
//         _lastDocuments[cacheKey] = docs.last;
//       }
      
//       return docs.map((doc) {
//         final data = doc.data() as Map<String, dynamic>;
//         data['id'] = doc.id; 
//         return TestItem.fromJson(data);
//       }).toList();
//     } on FirebaseException catch (e) {
//       throw ExceptionMapper.mapFirebaseException(e);
//     } catch (e) {
//       throw Exception('Failed to fetch tests: $e');
//     }
//   }

//   @override
//   Future<List<TestItem>> getTestsByCategory(
//     TestCategory category, {
//     int page = 0,
//     int pageSize = 5,
//     TestSortType sortType = TestSortType.recent,
//   }) async {
//     try {
//       final cacheKey = 'category_${category.name}_${sortType.name}';
      
//       if (page == 0) {
//         _lastDocuments[cacheKey] = null;
//       }

//       Query query = firestore.collection(testsCollection)
//           .where('isPublished', isEqualTo: true)
//           .where('category', isEqualTo: category.toString().split('.').last);

//       query = _applySorting(query, sortType);
//       query = query.limit(pageSize);
      
//       if (page > 0 && _lastDocuments[cacheKey] != null) {
//         query = query.startAfterDocument(_lastDocuments[cacheKey]!);
//       }
      
//       final querySnapshot = await query.get();
//       final docs = querySnapshot.docs;
      
//       if (docs.isNotEmpty) {
//         _lastDocuments[cacheKey] = docs.last;
//       }
      
//       return docs.map((doc) {
//         final data = doc.data() as Map<String, dynamic>;
//         data['id'] = doc.id;
//         return TestItem.fromJson(data);
//       }).toList();
//     } on FirebaseException catch (e) {
//       throw ExceptionMapper.mapFirebaseException(e);
//     } catch (e) {
//       throw Exception('Failed to fetch tests by category: $e');
//     }
//   }

//   @override
//   Future<bool> hasMoreTests(int currentCount, [TestSortType? sortType]) async {
//     try {
//       final countQuery = await firestore.collection(testsCollection)
//           .where('isPublished', isEqualTo: true)
//           .count()
//           .get();
      
//       return currentCount < countQuery.count!;
//     } on FirebaseException catch (e) {
//       throw ExceptionMapper.mapFirebaseException(e);
//     } catch (e) {
//       throw Exception('Failed to check for more tests: $e');
//     }
//   }

//   @override
//   Future<bool> hasMoreTestsByCategory(
//     TestCategory category, 
//     int currentCount, 
//     [TestSortType? sortType]
//   ) async {
//     try {
//       final countQuery = await firestore.collection(testsCollection)
//           .where('isPublished', isEqualTo: true)
//           .where('category', isEqualTo: category.toString().split('.').last)
//           .count()
//           .get();
      
//       return currentCount < countQuery.count!;
//     } on FirebaseException catch (e) {
//       throw ExceptionMapper.mapFirebaseException(e);
//     } catch (e) {
//       throw Exception('Failed to check for more tests by category: $e');
//     }
//   }

//   @override
//   Future<List<TestItem>> searchTests(String query) async {
//     try {
//       final normalizedQuery = query.toLowerCase();
      
//       final titleQuery = firestore.collection(testsCollection)
//           .where('isPublished', isEqualTo: true)
//           .where('titleLowerCase', isGreaterThanOrEqualTo: normalizedQuery)
//           .where('titleLowerCase', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
//           .limit(10);
      
//       final titleSnapshot = await titleQuery.get();
//       final List<TestItem> results = titleSnapshot.docs.map((doc) {
//         final data = doc.data();
//         data['id'] = doc.id;
//         return TestItem.fromJson(data);
//       }).toList();
      
//       if (results.length < 5) {
//         final descQuery = firestore.collection(testsCollection)
//             .where('isPublished', isEqualTo: true)
//             .where('descriptionLowerCase', isGreaterThanOrEqualTo: normalizedQuery)
//             .where('descriptionLowerCase', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
//             .limit(10);
            
//         final descSnapshot = await descQuery.get();
//         final descResults = descSnapshot.docs.map((doc) {
//           final data = doc.data();
//           data['id'] = doc.id;
//           return TestItem.fromJson(data);
//         }).toList();
        
//         for (final test in descResults) {
//           if (!results.any((t) => t.id == test.id)) {
//             results.add(test);
//           }
//         }
//       }
      
//       return results;
//     } on FirebaseException catch (e) {
//       throw ExceptionMapper.mapFirebaseException(e);
//     } catch (e) {
//       throw Exception('Failed to search tests: $e');
//     }
//   }

//   @override
//   Future<TestItem?> getTestById(String testId) async {
//     try {
//       final docSnapshot = await firestore.collection(testsCollection).doc(testId).get();
      
//       if (!docSnapshot.exists) {
//         return null;
//       }
      
//       final data = docSnapshot.data() as Map<String, dynamic>;
//       data['id'] = docSnapshot.id;
      
//       return TestItem.fromJson(data);
//     } on FirebaseException catch (e) {
//       throw ExceptionMapper.mapFirebaseException(e);
//     } catch (e) {
//       throw Exception('Failed to get test by ID: $e');
//     }
//   }

//   @override
//   Future<void> recordTestView(String testId, String userId) async {
//     try {
//       final interactionRef = firestore
//           .collection(testsCollection)
//           .doc(testId)
//           .collection(interactionsSubcollection)
//           .doc(userId);
      
//       final testRef = firestore.collection(testsCollection).doc(testId);
      
//       final results = await Future.wait([
//         interactionRef.get(),
//         testRef.get(),
//       ]);
      
//       final interactionDoc = results[0];
//       final testDoc = results[1];
      
//       if (!testDoc.exists) {
//         throw Exception('Test not found');
//       }
      
//       final hasViewed = interactionDoc.exists && 
//                        (interactionDoc.data())?['hasViewed'] == true;
      
//       if (!hasViewed) {
//         final batch = firestore.batch();
        
//         final existingData = interactionDoc.exists ? interactionDoc.data() : null;
        
//         batch.set(interactionRef, {
//           'hasViewed': true,
//           'viewedAt': FieldValue.serverTimestamp(),
//           'hasRated': existingData?['hasRated'] ?? false,
//           'rating': existingData?['rating'],
//           'ratedAt': existingData?['ratedAt'],
//           'completionCount': existingData?['completionCount'] ?? 0,
//         }, SetOptions(merge: true));
        
//         batch.update(testRef, {
//           'viewCount': FieldValue.increment(1),
//           'updatedAt': FieldValue.serverTimestamp(),
//         });
        
//         await batch.commit();
//         await _updateTestPopularity(testId);
//       }
//     } on FirebaseException catch (e) {
//       throw ExceptionMapper.mapFirebaseException(e);
//     } catch (e) {
//       throw Exception('Failed to record test view: $e');
//     }
//   }

//   @override
//   Future<void> rateTest(String testId, String userId, double rating) async {
//     try {
//       final interactionRef = firestore
//           .collection(testsCollection)
//           .doc(testId)
//           .collection(interactionsSubcollection)
//           .doc(userId);
      
//       final testRef = firestore.collection(testsCollection).doc(testId);
      
//       final results = await Future.wait([
//         interactionRef.get(),
//         testRef.get(),
//       ]);
      
//       final interactionDoc = results[0];
//       final testDoc = results[1];
      
//       if (!testDoc.exists) {
//         throw Exception('Test not found');
//       }
      
//       final testData = testDoc.data() as Map<String, dynamic>;
//       final currentRating = (testData['rating'] as num?)?.toDouble() ?? 0.0;
//       final currentRatingCount = testData['ratingCount'] as int? ?? 0;
      
//       final interactionData = interactionDoc.exists 
//           ? interactionDoc.data() 
//           : null;
      
//       final previousRating = interactionData?['rating'] as double?;
//       final hasRated = interactionData?['hasRated'] as bool? ?? false;
      
//       double newRating;
//       int newRatingCount;
      
//       if (hasRated && previousRating != null) {
//         final totalRating = currentRating * currentRatingCount;
//         final adjustedTotal = totalRating - previousRating + rating;
//         newRating = adjustedTotal / currentRatingCount;
//         newRatingCount = currentRatingCount;
//       } else {
//         final totalRating = currentRating * currentRatingCount;
//         newRating = (totalRating + rating) / (currentRatingCount + 1);
//         newRatingCount = currentRatingCount + 1;
//       }
      
//       final batch = firestore.batch();
      
//       batch.set(interactionRef, {
//         'hasRated': true,
//         'rating': rating,
//         'ratedAt': FieldValue.serverTimestamp(),
//         'hasViewed': interactionData?['hasViewed'] ?? true,
//         'viewedAt': interactionData?['viewedAt'] ?? FieldValue.serverTimestamp(),
//         'completionCount': (interactionData?['completionCount'] ?? 0) + 1,
//       }, SetOptions(merge: true));
      
//       batch.update(testRef, {
//         'rating': newRating,
//         'ratingCount': newRatingCount,
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
      
//       await batch.commit();
//       await _updateTestPopularity(testId);
//     } on FirebaseException catch (e) {
//       throw ExceptionMapper.mapFirebaseException(e);
//     } catch (e) {
//       throw Exception('Failed to rate test: $e');
//     }
//   }

//   @override
//   Future<void> recordTestCompletion(String testId, String userId) async {
//     try {
//       final interactionRef = firestore
//           .collection(testsCollection)
//           .doc(testId)
//           .collection(interactionsSubcollection)
//           .doc(userId);
      
//       final testRef = firestore.collection(testsCollection).doc(testId);
      
//       final interactionDoc = await interactionRef.get();
      
//       final existingData = interactionDoc.exists ? interactionDoc.data() : null;
      
//       final batch = firestore.batch();
      
//       batch.set(interactionRef, {
//         'hasViewed': true,
//         'viewedAt': existingData?['viewedAt'] ?? FieldValue.serverTimestamp(),
//         'hasRated': existingData?['hasRated'] ?? false,
//         'rating': existingData?['rating'],
//         'ratedAt': existingData?['ratedAt'],
//         'completionCount': (existingData?['completionCount'] ?? 0) + 1,
//         'lastCompletedAt': FieldValue.serverTimestamp(),
//       }, SetOptions(merge: true));
      
//       batch.update(testRef, {
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
      
//       await batch.commit();
//       await _updateTestPopularity(testId);
//     } on FirebaseException catch (e) {
//       throw ExceptionMapper.mapFirebaseException(e);
//     } catch (e) {
//       throw Exception('Failed to record test completion: $e');
//     }
//   }

//   @override
//   Future<UserTestInteraction?> getUserTestInteraction(String testId, String userId) async {
//     try {
//       final doc = await firestore
//           .collection(testsCollection)
//           .doc(testId)
//           .collection(interactionsSubcollection)
//           .doc(userId)
//           .get();
      
//       if (!doc.exists) {
//         return null;
//       }
      
//       final data = doc.data() as Map<String, dynamic>;
//       data['userId'] = userId;
//       data['testId'] = testId;
      
//       return UserTestInteraction.fromJson(data);
//     } on FirebaseException catch (e) {
//       throw ExceptionMapper.mapFirebaseException(e);
//     } catch (e) {
//       throw Exception('Failed to get user test interaction: $e');
//     }
//   }

//   Future<List<UserTestInteraction>> getTestInteractions(String testId, {
//     int limit = 100,
//   }) async {
//     try {
//       final querySnapshot = await firestore
//           .collection(testsCollection)
//           .doc(testId)
//           .collection(interactionsSubcollection)
//           .limit(limit)
//           .get();
      
//       return querySnapshot.docs.map((doc) {
//         final data = doc.data();
//         data['userId'] = doc.id;
//         data['testId'] = testId;
//         return UserTestInteraction.fromJson(data);
//       }).toList();
//     } on FirebaseException catch (e) {
//       throw ExceptionMapper.mapFirebaseException(e);
//     } catch (e) {
//       throw Exception('Failed to get test interactions: $e');
//     }
//   }

//   Future<Map<String, dynamic>> getTestAnalytics(String testId) async {
//     try {
//       final interactionsSnapshot = await firestore
//           .collection(testsCollection)
//           .doc(testId)
//           .collection(interactionsSubcollection)
//           .get();
      
//       int totalViews = 0;
//       int totalRatings = 0;
//       double totalRatingSum = 0;
//       int totalCompletions = 0;
      
//       for (final doc in interactionsSnapshot.docs) {
//         final data = doc.data();
        
//         if (data['hasViewed'] == true) totalViews++;
//         if (data['hasRated'] == true) {
//           totalRatings++;
//           totalRatingSum += (data['rating'] as num?)?.toDouble() ?? 0;
//         }
//         totalCompletions += (data['completionCount'] as int?) ?? 0;
//       }
      
//       return {
//         'totalViews': totalViews,
//         'totalRatings': totalRatings,
//         'averageRating': totalRatings > 0 ? totalRatingSum / totalRatings : 0.0,
//         'totalCompletions': totalCompletions,
//         'uniqueUsers': interactionsSnapshot.docs.length,
//       };
//     } on FirebaseException catch (e) {
//       throw ExceptionMapper.mapFirebaseException(e);
//     } catch (e) {
//       throw Exception('Failed to get test analytics: $e');
//     }
//   }

//   Query _applySorting(Query query, TestSortType sortType) {
//     switch (sortType) {
//       case TestSortType.recent:
//         return query.orderBy('createdAt', descending: true);
//       case TestSortType.popular:
//         return query.orderBy('popularity', descending: true);
//       case TestSortType.rating:
//         return query.orderBy('rating', descending: true);
//       case TestSortType.viewCount:
//         return query.orderBy('viewCount', descending: true);
//     }
//   }

//   Future<void> _updateTestPopularity(String testId) async {
//     try {
//       final testDoc = await firestore.collection(testsCollection).doc(testId).get();
      
//       if (!testDoc.exists) return;
      
//       final data = testDoc.data() as Map<String, dynamic>;
//       final viewCount = data['viewCount'] as int? ?? 0;
//       final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
//       final ratingCount = data['ratingCount'] as int? ?? 0;
//       final createdAt = data['createdAt'] as Timestamp?;
      
//       final daysSinceCreation = createdAt != null 
//           ? DateTime.now().difference(createdAt.toDate()).inDays 
//           : 0;
      
//       final recencyBonus = daysSinceCreation < 30 ? (30 - daysSinceCreation) * 0.5 : 0;
      
//       final popularity = (viewCount * 0.3) + 
//                         (rating * 20 * 0.4) + 
//                         (ratingCount * 0.2) + 
//                         recencyBonus;
      
//       await firestore.collection(testsCollection).doc(testId).update({
//         'popularity': popularity,
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
//     } catch (e) {
//       throw Exception('Failed to update test popularity: $e');
//     }
//   }
// }