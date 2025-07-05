import 'package:get_it/get_it.dart';
import 'package:korean_language_app/features/book_upload/data/datasources/book_upload_remote_datasource.dart';
import 'package:korean_language_app/features/book_upload/data/datasources/book_upload_remote_datasource_impl.dart';
import 'package:korean_language_app/features/book_upload/data/repositories/book_upload_repository_impl.dart';
import 'package:korean_language_app/features/book_upload/domain/repositories/book_upload_repository.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/book_upload_cubit.dart';
import 'package:korean_language_app/features/books/data/datasources/local/book_local_datasource.dart';
import 'package:korean_language_app/features/books/data/datasources/local/book_local_datasource_impl.dart';
import 'package:korean_language_app/features/books/data/datasources/remote/book_remote_datasource.dart';
import 'package:korean_language_app/features/books/data/datasources/remote/book_remote_datasource_impl.dart';
import 'package:korean_language_app/features/books/data/repositories/book_repository_impl.dart';
import 'package:korean_language_app/features/books/domain/repositories/book_repository.dart';
import 'package:korean_language_app/features/books/domain/usecase/check_book_permission_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecase/get_book_by_id_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecase/load_books_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecase/search_books_usecase.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_session/book_session_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/books_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_search/book_search_cubit.dart';
void registerBooksDependencies(GetIt sl) {

  // Cubits
  sl.registerFactory(() => BookUploadCubit(
    repository: sl(),
    authService: sl(),
    adminService: sl(),
  ));

  sl.registerFactory(() => BooksCubit(
    loadBooksUseCase: sl(),
    checkEditPermissionUseCase: sl(),
    getBookByIdUseCase: sl(),
    networkInfo: sl()
  ));

  sl.registerFactory(() => BookSearchCubit(
    searchBooksUseCase: sl(),
    checkEditPermissionUseCase: sl(),
  ));

  sl.registerFactory(() => BookSessionCubit(
    localDataSource: sl(),
  ));

  // Use cases
  sl.registerLazySingleton(() => LoadBooksUseCase(
    repository: sl(),
    authService: sl(),
  ));

  sl.registerLazySingleton(() => CheckBookEditPermissionUseCase(
    adminPermissionService: sl(),
    authService: sl(),
  ));

  sl.registerLazySingleton(() => GetBookByIdUseCase(
    repository: sl(),
    authService: sl(),
  ));

  sl.registerLazySingleton(() => SearchBooksUseCase(
    repository: sl(),
    authService: sl(),
  ));
  
  // Repositories
  sl.registerLazySingleton<BookUploadRepository>(
    () => BookUploadRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(), 
      adminService: sl(),
    )
  );

  sl.registerLazySingleton<BooksRepository>(
    () => BooksRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(), 
      localDataSource: sl(),
      authService: sl()
    )
  );
  
  // Data sources
  sl.registerLazySingleton<BookUploadRemoteDataSource>(
    () => FirestoreBookUploadDataSourceImpl(firestore: sl(), storage: sl()),
  );
  sl.registerLazySingleton<BooksLocalDataSource>(
    () => BooksLocalDataSourceImpl(storageService: sl()),
  );
  sl.registerLazySingleton<BooksRemoteDataSource>(
    () => FirestoreBooksDataSourceImpl(firestore: sl()),
  );
}