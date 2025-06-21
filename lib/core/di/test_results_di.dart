import 'package:get_it/get_it.dart';
import 'package:korean_language_app/features/test_results/data/datasources/test_results_local_datasources.dart';
import 'package:korean_language_app/features/test_results/data/datasources/test_results_local_datasources_impl.dart';
import 'package:korean_language_app/features/test_results/data/datasources/test_results_remote_datasources.dart';
import 'package:korean_language_app/features/test_results/data/datasources/test_results_remote_datasources_impl.dart';
import 'package:korean_language_app/features/test_results/data/repositories/test_result_repository_impl.dart';
import 'package:korean_language_app/features/test_results/domain/repositories/test_results_repository.dart';
import 'package:korean_language_app/features/test_results/domain/usecases/get_user_latest_result_usecase.dart';
import 'package:korean_language_app/features/test_results/domain/usecases/load_user_test_results_usecase.dart';
import 'package:korean_language_app/features/test_results/domain/usecases/save_test_result_usecase.dart';
import 'package:korean_language_app/features/test_results/presentation/bloc/test_results_cubit.dart';

void registerTestResultsDependencies(GetIt sl) {
  // Cubits
  sl.registerFactory(() => TestResultsCubit(
    saveTestResultUseCase: sl(),
    loadUserTestResultsUseCase: sl(),
    getUserLatestResultUseCase: sl(),
  ));

  // Use Cases
  sl.registerLazySingleton(() => SaveTestResultUseCase(
    repository: sl(),
    authService: sl(),
  ));

  sl.registerLazySingleton(() => LoadUserTestResultsUseCase(
    repository: sl(),
    authService: sl(),
  ));

  sl.registerLazySingleton(() => GetUserLatestResultUseCase(
    repository: sl(),
    authService: sl(),
  ));

  // Repository
  sl.registerLazySingleton<TestResultsRepository>(
    () => TestResultsRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data Sources
  sl.registerLazySingleton<TestResultsRemoteDataSource>(
    () => FirestoreTestResultsDataSourceImpl(
      firestore: sl(),
    ),
  );

  sl.registerLazySingleton<TestResultsLocalDataSource>(
    () => TestResultsLocalDataSourceImpl(
      storageService: sl(),
    ),
  );
}