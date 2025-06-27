import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:flutter/foundation.dart';

abstract class PdfManipulationService {
  Future<File> extractPagesAsNewPdf({
    required File sourcePdf,
    required List<int> pageNumbers,
    required String outputFileName,
  });
  
  Future<int> getPdfPageCount(File pdfFile);
  Future<List<Uint8List>> generatePageThumbnails(File pdfFile, {int maxPages = 50});
  Future<Uint8List> generateSinglePageThumbnail(File pdfFile, int pageNumber);
}

class PdfManipulationServiceImpl implements PdfManipulationService {
  
  @override
  Future<File> extractPagesAsNewPdf({
    required File sourcePdf,
    required List<int> pageNumbers,
    required String outputFileName,
  }) async {
    try {
      final document = await pdfx.PdfDocument.openFile(sourcePdf.path);
      final pdf = pw.Document();
      
      for (final pageNum in pageNumbers) {
        if (pageNum > 0 && pageNum <= document.pagesCount) {
          final page = await document.getPage(pageNum);
          final pageImage = await page.render(
            width: page.width,
            height: page.height,
          );
          await page.close();
          
          pdf.addPage(
            pw.Page(
              build: (pw.Context context) {
                return pw.Image(
                  pw.MemoryImage(pageImage!.bytes),
                  fit: pw.BoxFit.contain,
                );
              },
            ),
          );
        }
      }
      
      await document.close();
      
      final outputBytes = await pdf.save();
      
      final tempDir = await getTemporaryDirectory();
      final outputFile = File('${tempDir.path}/$outputFileName.pdf');
      await outputFile.writeAsBytes(outputBytes);
      
      return outputFile;
    } catch (e) {
      debugPrint('Error extracting PDF pages: $e');
      throw Exception('Failed to extract PDF pages: $e');
    }
  }
  
  @override
  Future<int> getPdfPageCount(File pdfFile) async {
    try {
      final document = await pdfx.PdfDocument.openFile(pdfFile.path);
      final pageCount = document.pagesCount;
      await document.close();
      return pageCount;
    } catch (e) {
      debugPrint('Error getting PDF page count: $e');
      return 0;
    }
  }
  
  @override
  Future<List<Uint8List>> generatePageThumbnails(File pdfFile, {int maxPages = 50}) async {
    try {
      final document = await pdfx.PdfDocument.openFile(pdfFile.path);
      
      final thumbnails = <Uint8List>[];
      final pageCount = document.pagesCount;
      final pagesToProcess = pageCount > maxPages ? maxPages : pageCount;
      
      for (int i = 1; i <= pagesToProcess; i++) {
        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: 200,
          height: 280,
        );
        await page.close();
        
        thumbnails.add(pageImage!.bytes);
      }
      
      await document.close();
      return thumbnails;
    } catch (e) {
      debugPrint('Error generating PDF thumbnails: $e');
      return [];
    }
  }
  
  @override
  Future<Uint8List> generateSinglePageThumbnail(File pdfFile, int pageNumber) async {
    try {
      final document = await pdfx.PdfDocument.openFile(pdfFile.path);
      
      if (pageNumber > document.pagesCount) {
        await document.close();
        throw Exception('Page number $pageNumber exceeds document page count');
      }
      
      final page = await document.getPage(pageNumber);
      final pageImage = await page.render(
        width: 200,
        height: 280,
      );
      await page.close();
      await document.close();
      
      return pageImage!.bytes;
    } catch (e) {
      debugPrint('Error generating single page thumbnail: $e');
      rethrow;
    }
  }
}