import 'package:get_it/get_it.dart';
import 'package:korean_language_app/features/book_upload/data/datasources/book_upload_remote_datasource.dart';
import 'package:korean_language_app/features/book_upload/data/datasources/book_upload_remote_datasource_impl.dart';
import 'package:korean_language_app/features/book_upload/data/repositories/book_upload_repository_impl.dart';
import 'package:korean_language_app/features/book_pdf_extractor/data/services/pdf_cache_service.dart';
import 'package:korean_language_app/features/book_pdf_extractor/data/services/pdf_manipulation_service.dart';
import 'package:korean_language_app/features/book_upload/domain/repositories/book_upload_repository.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/create_book_usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/create_book_with_chapters_usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/delete_book_usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/image_picker_usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/pdf_picker_usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/update_book_usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/update_book_with_chapters_usecase.dart';
import 'package:korean_language_app/features/book_pdf_extractor/presentation/bloc/book_editing_cubit.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/file_upload_cubit.dart';
import 'package:korean_language_app/features/books/domain/usecases/check_book_edit_permission_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/get_book_audio_track_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/get_book_pdf_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/get_chapter_audio_track_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/get_chapter_pdf_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/load_books_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/load_favorite_books_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/load_more_books_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/preload_book_audio_tracks_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/refresh_books_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/regenerate_book_image_url_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/search_books_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/search_favorite_books_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/toggle_favorite_book_usecase.dart';
import 'package:korean_language_app/shared/services/audio_cache_service.dart';
import 'package:korean_language_app/shared/services/image_cache_service.dart';
import 'package:korean_language_app/features/books/data/datasources/local/favorite_books_local_data_source.dart';
import 'package:korean_language_app/features/books/data/datasources/local/favorite_books_local_data_source_impl.dart';
import 'package:korean_language_app/features/books/data/datasources/remote/firestore_korean_books_remote_data_source_impl.dart';
import 'package:korean_language_app/features/books/data/datasources/local/korean_books_local_data_source_impl.dart';
import 'package:korean_language_app/features/books/data/datasources/local/korean_books_local_datasource.dart';
import 'package:korean_language_app/features/books/data/datasources/remote/korean_books_remote_data_source.dart';
import 'package:korean_language_app/features/books/data/repositories/favorite_book_repository_impl.dart';
import 'package:korean_language_app/features/books/data/repositories/korean_book_repository_impl.dart';
import 'package:korean_language_app/features/books/domain/repositories/favorite_book_repository.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_search/book_search_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/favorite_books/favorite_books_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/korean_books/korean_books_cubit.dart';

void registerBooksDependencies(GetIt sl) {
  // Services
  sl.registerLazySingleton<AudioCacheService>(
    () => AudioCacheService(storageService: sl())
  );
  sl.registerLazySingleton<ImageCacheService>(
    () => ImageCacheService(storageService: sl())
  );
  sl.registerLazySingleton<PdfManipulationService>(
    () => PdfManipulationServiceImpl()
  );
  sl.registerLazySingleton<PdfCacheService>(
    () => PdfCacheService(
      storageService: sl()
    )
  );
  
  // Book Upload Use Cases
  sl.registerLazySingleton(() => PickImageUseCase());
  sl.registerLazySingleton(() => PickPDFUseCase());
  
  sl.registerLazySingleton(() => CreateBookUseCase(
    repository: sl(),
    authService: sl(),
  ));
  
  sl.registerLazySingleton(() => CreateBookWithChaptersUseCase(
    repository: sl(),
    authService: sl(),
  ));
  
  sl.registerLazySingleton(() => UpdateBookUseCase(
    repository: sl(),
    authService: sl(),
  ));
  
  sl.registerLazySingleton(() => UpdateBookWithChaptersUseCase(
    repository: sl(),
    authService: sl(),
  ));
  
  sl.registerLazySingleton(() => DeleteBookUseCase(
    repository: sl(),
    authService: sl(),
  ));

  // Books Feature Use Cases
  sl.registerLazySingleton(() => LoadBooksUseCase(
    repository: sl(),
  ));
  
  sl.registerLazySingleton(() => LoadMoreBooksUseCase(
    repository: sl(),
  ));
  
  sl.registerLazySingleton(() => RefreshBooksUseCase(
    repository: sl(),
  ));
  
  sl.registerLazySingleton(() => GetBookPdfUseCase(
    repository: sl(),
  ));
  
  sl.registerLazySingleton(() => GetChapterPdfUseCase(
    repository: sl(),
  ));
  
  sl.registerLazySingleton(() => CheckBookEditPermissionUseCase(
    authService: sl(),
    adminService: sl(),
  ));
  
  sl.registerLazySingleton(() => RegenerateBookImageUrlUseCase(
    repository: sl(),
  ));
  
  sl.registerLazySingleton(() => SearchBooksUseCase(
    repository: sl(),
  ));

  sl.registerLazySingleton(() => GetBookAudioTrackUseCase(
    repository: sl(),
  ));

  sl.registerLazySingleton(() => GetChapterAudioTrackUseCase(
    repository: sl(),
  ));

  sl.registerLazySingleton(() => PreloadBookAudioTracksUseCase(
    repository: sl(),
  ));

  sl.registerLazySingleton(() => PreloadChapterAudioTracksUseCase(
    repository: sl(),
  ));

  // Favorite Books Use Cases
  sl.registerLazySingleton(() => LoadFavoriteBooksUseCase(
    repository: sl(),
  ));
  
  sl.registerLazySingleton(() => SearchFavoriteBooksUseCase(
    repository: sl(),
  ));
  
  sl.registerLazySingleton(() => ToggleFavoriteBookUseCase(
    repository: sl(),
  ));
  
  // Cubits with use case dependencies
  sl.registerFactory(() => KoreanBooksCubit(
    loadBooksUseCase: sl(),
    loadMoreBooksUseCase: sl(),
    refreshBooksUseCase: sl(),
    getBookPdfUseCase: sl(),
    getChapterPdfUseCase: sl(),
    checkBookEditPermissionUseCase: sl(),
    regenerateBookImageUrlUseCase: sl(),
    getBookAudioTrackUseCase: sl(),
    getChapterAudioTrackUseCase: sl(),
    preloadBookAudioTracksUseCase: sl(), 
    preloadChapterAudioTracksUseCase: sl(),
  ));

  sl.registerFactory(() => BookEditingCubit(
    pdfManipulationService: sl(), 
    pdfCacheService: sl()
  ));

  sl.registerFactory(() => BookSearchCubit(
    searchBooksUseCase: sl(),
    checkBookEditPermissionUseCase: sl(),
  ));

  sl.registerFactory(() => FavoriteBooksCubit(
    loadFavoriteBooksUseCase: sl(),
    searchFavoriteBooksUseCase: sl(),
    toggleFavoriteBookUseCase: sl(),
  ));
  
  // Upload related
  sl.registerFactory(() => FileUploadCubit(
    pickImageUseCase: sl(),
    pickPDFUseCase: sl(),
    createBookUseCase: sl(),
    createBookWithChaptersUseCase: sl(),
    updateBookUseCase: sl(),
    updateBookWithChaptersUseCase: sl(),
    deleteBookUseCase: sl(),
  ));
  
  sl.registerLazySingleton<BookUploadRepository>(
    () => BookUploadRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      adminService: sl(),
    )
  );
  
  sl.registerLazySingleton<BookUploadRemoteDataSource>(
    () => FirestoreBookUploadDataSource(
      firestore: sl(),
      storage: sl(),
    )
  );
  
  // Repositories
  sl.registerLazySingleton<KoreanBookRepository>(
    () => KoreanBookRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      imageCacheService: sl(),
      networkInfo: sl(), 
      audioCacheService: sl(),
    )
  );
  
  sl.registerLazySingleton<FavoriteBookRepository>(
    () => FavoriteBookRepositoryImpl(
      localDataSource: sl(),
      networkInfo: sl(),
    )
  );
  
  // Data sources
  sl.registerLazySingleton<KoreanBooksRemoteDataSource>(
    () => FirestoreKoreanBooksDataSource(firestore: sl(), storage: sl()),
  );
  
  sl.registerLazySingleton<KoreanBooksLocalDataSource>(
    () => KoreanBooksLocalDataSourceImpl(storageService: sl())
  );
  
  sl.registerLazySingleton<FavoriteBooksLocalDataSource>(
    () => FavoriteBooksLocalDataSourceImpl(storageService: sl())
  );
}