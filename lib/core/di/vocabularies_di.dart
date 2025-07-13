import 'package:get_it/get_it.dart';
import 'package:korean_language_app/features/vocabularies/data/datasources/local/session/vocabulary_session_local_datasource.dart';
import 'package:korean_language_app/features/vocabularies/data/datasources/local/session/vocabulary_session_local_datasource_impl.dart';
import 'package:korean_language_app/features/vocabularies/data/datasources/local/vocabularies_local_datasource.dart';
import 'package:korean_language_app/features/vocabularies/data/datasources/local/vocabularies_local_datasource_impl.dart';
import 'package:korean_language_app/features/vocabularies/data/datasources/remote/firestore_vocabularies_remote_datasource_impl.dart';
import 'package:korean_language_app/features/vocabularies/data/datasources/remote/vocabularies_remote_datasource.dart';
import 'package:korean_language_app/features/vocabularies/data/repositories/vocabularies_repository_impl.dart';
import 'package:korean_language_app/features/vocabularies/domain/repositories/vocabularies_repository.dart';
import 'package:korean_language_app/features/vocabularies/domain/usecases/get_vocabulary_by_id_usecase.dart';
import 'package:korean_language_app/features/vocabularies/domain/usecases/load_vocabularies_usecase.dart';
import 'package:korean_language_app/features/vocabularies/domain/usecases/rate_vocabulary_usecase.dart';
import 'package:korean_language_app/features/vocabularies/domain/usecases/search_vocabularies_usecase.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabularies_cubit.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabulary_search/vocabulary_search_cubit.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabulary_session/vocabulary_session_cubit.dart';
import 'package:korean_language_app/features/vocabulary_upload/data/datasources/vocabulary_upload_remote_datasource.dart';
import 'package:korean_language_app/features/vocabulary_upload/data/datasources/vocabulary_upload_remote_datasource_impl.dart';
import 'package:korean_language_app/features/vocabulary_upload/data/repositories/vocabulary_upload_repository_impl.dart';
import 'package:korean_language_app/features/vocabulary_upload/domain/repositories/vocabulary_upload_repository.dart';
import 'package:korean_language_app/features/vocabulary_upload/presentation/bloc/vocabulary_upload_cubit.dart';

void registerVocabulariesDependencies(GetIt sl) {

  // Cubits
  sl.registerFactory(() => VocabularyUploadCubit(
    repository: sl(),
    authService: sl(),
    adminService: sl(),
  ));

  sl.registerFactory(() => VocabulariesCubit(
    loadVocabulariesUseCase: sl(), 
    getVocabularyByIdUseCase: sl(),
    rateVocabularyUseCase: sl(),
    networkInfo: sl(),
    
  ));
  
  sl.registerFactory(() => VocabularySessionCubit(
    localDataSource: sl(),
  ));

  sl.registerFactory(() => VocabularySearchCubit(
    searchVocabulariesUseCase: sl(),
  ));

  // Use cases

  sl.registerLazySingleton(() => LoadVocabulariesUseCase(
    repository: sl(),
    authService: sl(),
  ));

  sl.registerLazySingleton(() => GetVocabularyByIdUseCase(
    repository: sl(),
    authService: sl(),
  ));

  sl.registerLazySingleton(() => RateVocabularyUseCase(
    repository: sl(),
    authService: sl(),
  ));

  sl.registerLazySingleton(() => SearchVocabulariesUseCase(
    repository: sl(),
    authService: sl(),
  ));

  
  // Repositories
  sl.registerLazySingleton<VocabularyUploadRepository>(
    () => VocabularyUploadRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(), 
      adminService: sl(),
    )
  );

  sl.registerLazySingleton<VocabulariesRepository>(
    () => VocabulariesRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(), 
      localDataSource: sl(),
      authService: sl(),
    )
  );

  
  // Data sources
  sl.registerLazySingleton<VocabularyUploadRemoteDataSource>(
    () => FirestoreVocabularyUploadDataSourceImpl(firestore: sl(), storage: sl()),
  );
  sl.registerLazySingleton<VocabulariesLocalDataSource>(
    () => VocabulariesLocalDataSourceImpl(storageService: sl()),
  );
  sl.registerLazySingleton<VocabulariesRemoteDataSource>(
    () => FirestoreVocabulariesDataSourceImpl(firestore: sl()),
  );

  sl.registerLazySingleton<VocabularySessionLocalDataSource>(
    () => VocabularySessionLocalDataSourceImpl(storageService: sl()),
  );
}