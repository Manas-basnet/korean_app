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
  //Cubits/Blocs
  sl.registerFactory(() => TestsCubit(
    loadTestsUseCase: sl(),
    checkEditPermissionUseCase: sl(),
    rateTestUseCase: sl(),
    searchTestsUseCase: sl(),
    getTestByIdUseCase: sl(),
    startTestSessionUseCase: sl(),
    networkInfo: sl(), 
  ));
  sl.registerFactory(() => TestSearchCubit(repository: sl(), authService: sl(), adminService: sl()));
  sl.registerFactory(() => TestSessionCubit(
    testsRepository: sl(),
    testResultsRepository: sl(), 
    authService: sl(),
  ));
  
  //Repositories
  sl.registerLazySingleton<TestsRepository>(
    () => TestsRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      localDataSource: sl(),
      authService: sl(),
    ),
  );
  
  //Datasources
  sl.registerLazySingleton<TestsRemoteDataSource>(
    () => FirestoreTestsDataSourceImpl(firestore: sl()),
  );
  
  sl.registerLazySingleton<TestsLocalDataSourceImpl>(
    () => TestsLocalDataSourceImpl(storageService: sl()),
  );
  sl.registerLazySingleton<TestsLocalDataSource>(
    () => sl<TestsLocalDataSourceImpl>(),
  );

  //Use Cases
  sl.registerLazySingleton(
    () => LoadTestsUseCase(
      repository: sl(), 
      authService: sl()
    )
  );
  sl.registerLazySingleton(
    () => CheckTestEditPermissionSimpleUseCase(
      authService: sl(), 
      adminPermissionService: sl()
    )
  );
  sl.registerLazySingleton(
    () => RateTestUseCase(
      repository: sl(), 
      authService: sl()
    )
  );
  sl.registerLazySingleton(
    () => SearchTestsUseCase(
      repository: sl(), 
      authService: sl()
    )
  );
  sl.registerLazySingleton(
    () => GetTestByIdUseCase(
      repository: sl(), 
      authService: sl()
    )
  );
  sl.registerLazySingleton(
    () => StartTestSessionUseCase(
      repository: sl(), 
      authService: sl()
    )
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