import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:printing/printing.dart';

abstract class PdfManipulationService {
  Future<File> extractPagesAsNewPdf({
    required File sourcePdf,
    required List<int> pageNumbers,
    required String outputFileName,
  });
  
  Future<int> getPdfPageCount(File pdfFile);
  
  Future<List<Uint8List>> generatePageThumbnails(
    File pdfFile, {
    int maxPages = 50,
    Function(double)? onProgress,
  });
  
  Stream<Uint8List> generatePageThumbnailsStream(
    File pdfFile, {
    int maxPages = 50,
    Function(double)? onProgress,
  });
  
  Future<Uint8List> generateSinglePageThumbnail(File pdfFile, int pageNumber);
}

class PureDartPdfManipulationService implements PdfManipulationService {
  static const double thumbnailDpi = 150.0;
  static const int batchSize = 5;
  
  @override
  Future<File> extractPagesAsNewPdf({
    required File sourcePdf,
    required List<int> pageNumbers,
    required String outputFileName,
  }) async {
    try {
      final bytes = await sourcePdf.readAsBytes();
      final sourceDocument = PdfDocument(inputBytes: bytes);
      final newDocument = PdfDocument();
      
      for (int pageNum in pageNumbers) {
        if (pageNum > 0 && pageNum <= sourceDocument.pages.count) {
          final page = sourceDocument.pages[pageNum - 1];
          newDocument.pages.add().graphics.drawPdfTemplate(
            page.createTemplate(),
            Offset.zero,
          );
        }
      }
      
      final outputBytes = await newDocument.save();
      sourceDocument.dispose();
      newDocument.dispose();
      
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
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;
      document.dispose();
      return pageCount;
    } catch (e) {
      debugPrint('Error getting PDF page count: $e');
      return 0;
    }
  }
  
  @override
  Future<List<Uint8List>> generatePageThumbnails(
    File pdfFile, {
    int maxPages = 50,
    Function(double)? onProgress,
  }) async {
    try {
      final thumbnails = <Uint8List>[];
      final pageCount = await getPdfPageCount(pdfFile);
      final pagesToProcess = pageCount > maxPages ? maxPages : pageCount;
      final pdfBytes = await pdfFile.readAsBytes();
      
      for (int i = 0; i < pagesToProcess; i++) {
        try {
          // Generate raster for single page
          await for (final page in Printing.raster(
            pdfBytes,
            pages: [i],
            dpi: thumbnailDpi,
          )) {
            // Convert PdfRaster to PNG bytes
            final pngBytes = await page.toPng();
            thumbnails.add(pngBytes);
            break; // Only need the first (and only) page
          }
        } catch (e) {
          debugPrint('Error generating thumbnail for page ${i + 1}: $e');
          // Continue with next page instead of failing completely
        }
        
        onProgress?.call((i + 1) / pagesToProcess);
        
        // Add small delay every batch to prevent blocking UI
        if ((i + 1) % batchSize == 0) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
      
      return thumbnails;
    } catch (e) {
      debugPrint('Error generating PDF thumbnails: $e');
      return [];
    }
  }
  
  @override
  Stream<Uint8List> generatePageThumbnailsStream(
    File pdfFile, {
    int maxPages = 50,
    Function(double)? onProgress,
  }) async* {
    try {
      final pageCount = await getPdfPageCount(pdfFile);
      final pagesToProcess = pageCount > maxPages ? maxPages : pageCount;
      final pdfBytes = await pdfFile.readAsBytes();
      
      for (int i = 0; i < pagesToProcess; i++) {
        try {
          await for (final page in Printing.raster(
            pdfBytes,
            pages: [i],
            dpi: thumbnailDpi,
          )) {
            final pngBytes = await page.toPng();
            yield pngBytes;
            break; // Only need the first (and only) page
          }
        } catch (e) {
          debugPrint('Error generating thumbnail for page ${i + 1}: $e');
          // Continue with next page
        }
        
        onProgress?.call((i + 1) / pagesToProcess);
        
        if ((i + 1) % batchSize == 0) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
    } catch (e) {
      debugPrint('Error generating PDF thumbnails stream: $e');
    }
  }
  
  @override
  Future<Uint8List> generateSinglePageThumbnail(File pdfFile, int pageNumber) async {
    try {
      final pageCount = await getPdfPageCount(pdfFile);
      
      if (pageNumber > pageCount || pageNumber < 1) {
        throw Exception('Page number $pageNumber is out of range (1-$pageCount)');
      }
      
      final pdfBytes = await pdfFile.readAsBytes();
      
      // Convert to 0-based index for the raster API
      await for (final page in Printing.raster(
        pdfBytes,
        pages: [pageNumber - 1],
        dpi: thumbnailDpi,
      )) {
        // Convert PdfRaster to PNG bytes and return
        return await page.toPng();
      }
      
      throw Exception('Failed to render page $pageNumber');
    } catch (e) {
      debugPrint('Error generating single page thumbnail: $e');
      rethrow;
    }
  }
}