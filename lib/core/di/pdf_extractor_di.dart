import 'package:get_it/get_it.dart';
import 'package:korean_language_app/features/book_pdf_extractor/data/services/pdf_manipulation_service.dart';
import 'package:korean_language_app/features/book_pdf_extractor/data/services/pdf_cache_service.dart';
import 'package:korean_language_app/features/book_pdf_extractor/data/repositories/pdf_extractor_repository_impl.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/repositories/pdf_extractor_repository.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/usecases/clear_all_cache_usecase.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/usecases/load_pdf_pages_usecase.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/usecases/generate_chapter_pdfs_usecase.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/usecases/convert_to_book_chapters_usecase.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/usecases/load_pdf_pages_with_progress_usecase.dart';
import 'package:korean_language_app/features/book_pdf_extractor/presentation/bloc/pdf_extractor_cubit.dart';

void registerPdfExtractorDependencies(GetIt sl) {
  // Cubits
  sl.registerFactory(() => PdfExtractorCubit(
    loadPdfPagesUseCase: sl(),
    generateChapterPdfsUseCase: sl(),
    convertToBookChaptersUseCase: sl(),
    loadPdfPagesWithProgressUseCase: sl(),
    clearAllCacheUseCase: sl()
  ));

  // Use Cases
  sl.registerLazySingleton(() => LoadPdfPagesUseCase(sl()));
  sl.registerLazySingleton(() => GenerateChapterPdfsUseCase(sl()));
  sl.registerLazySingleton(() => ConvertToBookChaptersUseCase(sl()));
  sl.registerLazySingleton(() => LoadPdfPagesWithProgressUseCase(sl()));
  sl.registerLazySingleton(() => ClearAllCacheUseCase(sl()));

  // Repository
  sl.registerLazySingleton<PdfExtractorRepository>(
    () => PdfExtractorRepositoryImpl(
      pdfManipulationService: sl(),
      pdfCacheService: sl(),
    ),
  );

  // Services
  sl.registerLazySingleton<PdfManipulationService>(
    () => PureDartPdfManipulationService(),
  );

  sl.registerLazySingleton<PdfCacheService>(
    () => PdfCacheService(
      storageService: sl(),
    ),
  );
}