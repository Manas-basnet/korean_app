import 'package:get_it/get_it.dart';
import 'package:korean_language_app/features/tests/data/datasources/firestore_tests_remote_datasource_impl.dart';
import 'package:korean_language_app/features/tests/data/datasources/tests_local_datasource.dart';
import 'package:korean_language_app/features/tests/data/datasources/tests_local_datasource_impl.dart';
import 'package:korean_language_app/features/tests/data/datasources/tests_remote_datasource.dart';
import 'package:korean_language_app/features/tests/data/repositories/tests_repository_impl.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';
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
  sl.registerFactory(() => TestsCubit(repository: sl(), authService: sl(), adminService: sl()));
  sl.registerFactory(() => TestSearchCubit(repository: sl(), authService: sl(), adminService: sl()));
  sl.registerFactory(() => TestSessionCubit(
    testResultsRepository: sl(), 
    authService: sl(),
  ));
  
  sl.registerLazySingleton<TestsRepository>(
    () => TestsRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      localDataSource: sl(),
      authService: sl(),
    ),
  );
  
  sl.registerLazySingleton<TestsRemoteDataSource>(
    () => FirestoreTestsDataSourceImpl(firestore: sl()),
  );
  
  sl.registerLazySingleton<TestsLocalDataSourceImpl>(
    () => TestsLocalDataSourceImpl(storageService: sl()),
  );
  sl.registerLazySingleton<TestsLocalDataSource>(
    () => sl<TestsLocalDataSourceImpl>(),
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