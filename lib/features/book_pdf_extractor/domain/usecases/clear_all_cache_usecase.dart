import 'package:korean_language_app/features/book_pdf_extractor/domain/repositories/pdf_extractor_repository.dart';

class ClearAllCacheUseCase {
  final PdfExtractorRepository _repository;

  ClearAllCacheUseCase(this._repository);

  Future<void> call() async {
    await _repository.clearAllCache();
  }
}