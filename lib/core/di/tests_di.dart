import 'package:get_it/get_it.dart';
import 'package:korean_language_app/features/tests/data/datasources/remote/firestore_tests_remote_datasource_impl.dart';
import 'package:korean_language_app/features/tests/data/datasources/local/tests_local_datasource.dart';
import 'package:korean_language_app/features/tests/data/datasources/local/tests_local_datasource_impl.dart';
import 'package:korean_language_app/features/tests/data/datasources/remote/tests_remote_datasource.dart';
import 'package:korean_language_app/features/tests/data/repositories/tests_repository_impl.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';
import 'package:korean_language_app/features/tests/domain/usecases/check_test_edit_permission_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/get_test_by_id_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/load_tests_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/rate_test_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/search_tests_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/start_test_session_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/complete_test_session_usecase.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_session/test_session_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_search/test_search_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/tests_cubit.dart';
import 'package:korean_language_app/features/unpublished_tests/data/datasources/unpublished_tests_local_datasource.dart';
import 'package:korean_language_app/features/unpublished_tests/data/datasources/unpublished_tests_local_datasource_impl.dart';
import 'package:korean_language_app/features/unpublished_tests/data/datasources/unpublished_tests_remote_datasource.dart';
import 'package:korean_language_app/features/unpublished_tests/data/datasources/unpublished_tests_remote_datasource_impl.dart';
import 'package:korean_language_app/features/unpublished_tests/data/repositories/unpublished_tests_repository_impl.dart';
import 'package:korean_language_app/features/unpublished_tests/domain/repositories/unpublished_tests_repository.dart';
import 'package:korean_language_app/features/unpublished_tests/presentation/bloc/unpublished_tests_cubit.dart';

void registerTestsDependencies(GetIt sl) {
  // Cubits
  sl.registerFactory(() => TestsCubit(
    loadTestsUseCase: sl(),
    checkEditPermissionUseCase: sl(),
    rateTestUseCase: sl(),
    getTestByIdUseCase: sl(),
    startTestSessionUseCase: sl(),
    networkInfo: sl(),
  ));

  sl.registerFactory(() => TestSessionCubit(
    completeTestSessionUseCase: sl(),
    rateTestUseCase: sl(),
    authService: sl(),
  ));

  sl.registerFactory(() => TestSearchCubit(
    searchTestsUseCase: sl(),
    checkEditPermissionUseCase: sl(),
  ));

  // Use Cases
  sl.registerLazySingleton(() => LoadTestsUseCase(
    repository: sl(),
    authService: sl(),
  ));

  sl.registerLazySingleton(() => RateTestUseCase(
    repository: sl(),
    authService: sl(),
  ));

  sl.registerLazySingleton(() => CheckTestEditPermissionUseCase(
    adminPermissionService: sl(),
    authService: sl(),
  ));

  sl.registerLazySingleton(() => SearchTestsUseCase(
    repository: sl(),
    authService: sl(),
  ));

  sl.registerLazySingleton(() => GetTestByIdUseCase(
    repository: sl(),
    authService: sl(),
  ));

  sl.registerLazySingleton(() => StartTestSessionUseCase(
    repository: sl(),
    authService: sl(),
  ));

  // New Test Session Use Cases
  sl.registerLazySingleton(() => CompleteTestSessionUseCase(
    saveTestResultUseCase: sl(),
    authService: sl(),
  ));

  // Repository
  sl.registerLazySingleton<TestsRepository>(
    () => TestsRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      localDataSource: sl(),
      authService: sl(),
    ),
  );

  // Data Sources
  sl.registerLazySingleton<TestsRemoteDataSource>(
    () => FirestoreTestsDataSourceImpl(
      firestore: sl(),
    ),
  );

  sl.registerLazySingleton<TestsLocalDataSource>(
    () => TestsLocalDataSourceImpl(
      storageService: sl(),
    ),
  );
}

void registerUnpublishedTestsDependencies(GetIt sl) {
  sl.registerFactory(() => UnpublishedTestsCubit(
    repository: sl(),
    authService: sl(),
    adminService: sl(),
  ));
  
  sl.registerLazySingleton<UnpublishedTestsRepository>(
    () => UnpublishedTestsRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
      authService: sl(),
    )
  );
  
  sl.registerLazySingleton<UnpublishedTestsRemoteDataSource>(
    () => FirestoreUnpublishedTestsDataSourceImpl(firestore: sl()),
  );
  
  sl.registerLazySingleton<UnpublishedTestsLocalDataSource>(
    () => UnpublishedTestsLocalDataSourceImpl(storageService: sl())
  );
}