import 'package:get_it/get_it.dart';
import 'package:korean_language_app/features/book_upload/data/datasources/book_upload_remote_datasource.dart';
import 'package:korean_language_app/features/book_upload/data/datasources/book_upload_remote_datasource_impl.dart';
import 'package:korean_language_app/features/book_upload/data/repositories/book_upload_repository_impl.dart';
import 'package:korean_language_app/features/book_upload/domain/repositories/book_upload_repository.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/book_upload_cubit.dart';
void registerBooksDependencies(GetIt sl) {

  // Cubits with use case dependencies
  sl.registerFactory(() => BookUploadCubit(
    repository: sl(),
    authService: sl(),
    adminService: sl(),
  ));
  
  // Repositories
  sl.registerLazySingleton<BookUploadRepository>(
    () => BookUploadRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(), 
      adminService: sl(),
    )
  );
  
  // Data sources
  sl.registerLazySingleton<BookUploadRemoteDataSource>(
    () => FirestoreBookUploadDataSourceImpl(firestore: sl(), storage: sl()),
  );
}