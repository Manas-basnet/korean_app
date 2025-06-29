enum BookUploadType {
  singlePdf,
  chapterWise;

  String get displayName {
    switch (this) {
      case BookUploadType.singlePdf:
        return 'Single PDF';
      case BookUploadType.chapterWise:
        return 'Chapter-wise';
    }
  }

  String get description {
    switch (this) {
      case BookUploadType.singlePdf:
        return 'Upload one PDF file containing the entire book';
      case BookUploadType.chapterWise:
        return 'Upload separate PDF files for each chapter';
    }
  }
}