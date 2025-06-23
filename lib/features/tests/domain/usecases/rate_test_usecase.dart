// import 'dart:developer' as dev;
// import 'package:equatable/equatable.dart';
// import 'package:korean_language_app/core/usecases/usecase.dart';
// import 'package:korean_language_app/core/errors/api_result.dart';
// import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';
// import 'package:korean_language_app/shared/services/auth_service.dart';

// class RateTestParams extends Equatable {
//   final String testId;
//   final double rating;

//   const RateTestParams({
//     required this.testId,
//     required this.rating,
//   });

//   @override
//   List<Object?> get props => [testId, rating];
// }

// class RateTestUseCase implements UseCase<void, RateTestParams> {
//   final TestsRepository repository;
//   final AuthService authService;

//   RateTestUseCase({
//     required this.repository,
//     required this.authService,
//   });

//   @override
//   Future<ApiResult<void>> execute(RateTestParams params) async {
//     try {
//       dev.log('RateTestUseCase: Rating test ${params.testId} with rating ${params.rating}');

//       // Business Rule: Validate rating range
//       if (params.rating < 1.0 || params.rating > 5.0) {
//         dev.log('RateTestUseCase: Invalid rating ${params.rating}');
//         return ApiResult.failure(
//           'Rating must be between 1.0 and 5.0', 
//           FailureType.validation,
//         );
//       }

//       // Business Rule: Must be authenticated to rate
//       final user = authService.getCurrentUser();
//       if (user == null) {
//         dev.log('RateTestUseCase: User not authenticated');
//         return ApiResult.failure(
//           'You must be logged in to rate a test', 
//           FailureType.auth,
//         );
//       }

//       // Business Rule: Validate test ID
//       if (params.testId.isEmpty) {
//         return ApiResult.failure(
//           'Test ID cannot be empty', 
//           FailureType.validation,
//         );
//       }

//       // Business Rule: Check if test exists (optional - depends on requirements)
//       final testResult = await repository.getTestById(params.testId);
//       final testExists = testResult.fold(
//         onSuccess: (test) => test != null,
//         onFailure: (_, __) => false,
//       );

//       if (!testExists) {
//         dev.log('RateTestUseCase: Test ${params.testId} not found');
//         return ApiResult.failure(
//           'Test not found', 
//           FailureType.notFound,
//         );
//       }

//       // Business Rule: Users cannot rate their own tests (optional)
//       final test = testResult.fold(
//         onSuccess: (test) => test,
//         onFailure: (_, __) => null,
//       );

//       if (test != null && test.creatorUid == user.uid) {
//         dev.log('RateTestUseCase: User trying to rate own test');
//         return ApiResult.failure(
//           'You cannot rate your own test', 
//           FailureType.validation,
//         );
//       }

//       // Business Rule: Submit rating using the new combined method
//       // This will update both view count (if 5+ minutes passed) and rating in one operation
//       final result = await repository.completeTestWithViewAndRating(
//         params.testId, 
//         user.uid, 
//         params.rating,
//       );

//       return result.fold(
//         onSuccess: (_) {
//           dev.log('RateTestUseCase: Successfully rated test ${params.testId}');
//           return ApiResult.success(null);
//         },
//         onFailure: (message, type) {
//           dev.log('RateTestUseCase: Failed to rate test - $message');
//           return ApiResult.failure(message, type);
//         },
//       );

//     } catch (e) {
//       dev.log('RateTestUseCase: Unexpected error - $e');
//       return ApiResult.failure('Failed to rate test: $e', FailureType.unknown);
//     }
//   }
// }