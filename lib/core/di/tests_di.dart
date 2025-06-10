import 'package:get_it/get_it.dart';
import 'package:korean_language_app/features/tests/data/datasources/firestore_tests_remote_datasource_impl.dart';
import 'package:korean_language_app/features/tests/data/datasources/tests_local_datasource.dart';
import 'package:korean_language_app/features/tests/data/datasources/tests_local_datasource_impl.dart';
import 'package:korean_language_app/features/tests/data/datasources/tests_remote_datasource.dart';
import 'package:korean_language_app/features/tests/data/repositories/tests_repository_impl.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_session/test_session_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/tests_cubit.dart';

void registerTestsDependencies(GetIt sl) {
  // Cubits
  sl.registerFactory(() => TestsCubit(repository: sl(), authService: sl(), adminService: sl()));
  sl.registerFactory(() => TestSessionCubit(testResultsRepository: sl(), authService: sl()));
  
  // Repository
  sl.registerLazySingleton<TestsRepository>(
    () => TestsRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      localDataSource: sl(),
    ),
  );
  
  // Data Sources
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