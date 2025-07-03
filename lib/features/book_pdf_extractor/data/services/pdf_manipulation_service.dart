// import 'dart:io';
// import 'dart:async';
// import 'package:path_provider/path_provider.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:pdfx/pdfx.dart' as pdfx;
// import 'package:flutter/foundation.dart';

// abstract class PdfManipulationService {
//   Future<File> extractPagesAsNewPdf({
//     required File sourcePdf,
//     required List<int> pageNumbers,
//     required String outputFileName,
//   });
  
//   Future<int> getPdfPageCount(File pdfFile);
  
//   Future<List<Uint8List>> generatePageThumbnails(
//     File pdfFile, {
//     int maxPages = 50,
//     Function(double)? onProgress,
//   });
  
//   Stream<Uint8List> generatePageThumbnailsStream(
//     File pdfFile, {
//     int maxPages = 50,
//     Function(double)? onProgress,
//   });
  
//   Future<Uint8List> generateSinglePageThumbnail(File pdfFile, int pageNumber);
// }

// class PdfManipulationServiceImpl implements PdfManipulationService {
//   static const double thumbnailWidth = 400;
//   static const double thumbnailHeight = 560;
//   static const int batchSize = 5;
  
//   @override
//   Future<File> extractPagesAsNewPdf({
//     required File sourcePdf,
//     required List<int> pageNumbers,
//     required String outputFileName,
//   }) async {
//     pdfx.PdfDocument? document;
//     try {
//       document = await pdfx.PdfDocument.openFile(sourcePdf.path);
//       final pdf = pw.Document();
      
//       for (int i = 0; i < pageNumbers.length; i++) {
//         final pageNum = pageNumbers[i];
//         if (pageNum > 0 && pageNum <= document.pagesCount) {
//           pdfx.PdfPage? page;
//           try {
//             page = await document.getPage(pageNum);
//             final pageImage = await page.render(
//               width: page.width,
//               height: page.height,
//             );
            
//             if (pageImage != null) {
//               pdf.addPage(
//                 pw.Page(
//                   build: (pw.Context context) {
//                     return pw.Image(
//                       pw.MemoryImage(pageImage.bytes),
//                       fit: pw.BoxFit.contain,
//                     );
//                   },
//                 ),
//               );
//             }
//           } finally {
//             await page?.close();
//           }
//         }
//       }
      
//       final outputBytes = await pdf.save();
      
//       final tempDir = await getTemporaryDirectory();
//       final outputFile = File('${tempDir.path}/$outputFileName.pdf');
//       await outputFile.writeAsBytes(outputBytes);
      
//       return outputFile;
//     } catch (e) {
//       debugPrint('Error extracting PDF pages: $e');
//       throw Exception('Failed to extract PDF pages: $e');
//     } finally {
//       await document?.close();
//     }
//   }
  
//   @override
//   Future<int> getPdfPageCount(File pdfFile) async {
//     pdfx.PdfDocument? document;
//     try {
//       document = await pdfx.PdfDocument.openFile(pdfFile.path);
//       return document.pagesCount;
//     } catch (e) {
//       debugPrint('Error getting PDF page count: $e');
//       return 0;
//     } finally {
//       await document?.close();
//     }
//   }
  
//   @override
//   Future<List<Uint8List>> generatePageThumbnails(
//     File pdfFile, {
//     int maxPages = 50,
//     Function(double)? onProgress,
//   }) async {
//     pdfx.PdfDocument? document;
//     try {
//       document = await pdfx.PdfDocument.openFile(pdfFile.path);
      
//       final thumbnails = <Uint8List>[];
//       final pageCount = document.pagesCount;
//       final pagesToProcess = pageCount > maxPages ? maxPages : pageCount;
      
//       for (int i = 1; i <= pagesToProcess; i++) {
//         pdfx.PdfPage? page;
//         try {
//           page = await document.getPage(i);
//           final pageImage = await page.render(
//             width: thumbnailWidth,
//             height: thumbnailHeight,
//           );
          
//           if (pageImage != null) {
//             thumbnails.add(pageImage.bytes);
//           }
          
//           onProgress?.call(i / pagesToProcess);
          
//           if (i % batchSize == 0) {
//             await Future.delayed(const Duration(milliseconds: 10));
//           }
//         } finally {
//           await page?.close();
//         }
//       }
      
//       return thumbnails;
//     } catch (e) {
//       debugPrint('Error generating PDF thumbnails: $e');
//       return [];
//     } finally {
//       await document?.close();
//     }
//   }
  
//   @override
//   Stream<Uint8List> generatePageThumbnailsStream(
//     File pdfFile, {
//     int maxPages = 50,
//     Function(double)? onProgress,
//   }) async* {
//     pdfx.PdfDocument? document;
//     try {
//       document = await pdfx.PdfDocument.openFile(pdfFile.path);
      
//       final pageCount = document.pagesCount;
//       final pagesToProcess = pageCount > maxPages ? maxPages : pageCount;
      
//       for (int i = 1; i <= pagesToProcess; i++) {
//         pdfx.PdfPage? page;
//         try {
//           page = await document.getPage(i);
//           final pageImage = await page.render(
//             width: thumbnailWidth,
//             height: thumbnailHeight,
//           );
          
//           if (pageImage != null) {
//             yield pageImage.bytes;
//           }
          
//           onProgress?.call(i / pagesToProcess);
          
//           if (i % batchSize == 0) {
//             await Future.delayed(const Duration(milliseconds: 10));
//           }
//         } finally {
//           await page?.close();
//         }
//       }
//     } catch (e) {
//       debugPrint('Error generating PDF thumbnails stream: $e');
//     } finally {
//       await document?.close();
//     }
//   }
  
//   @override
//   Future<Uint8List> generateSinglePageThumbnail(File pdfFile, int pageNumber) async {
//     pdfx.PdfDocument? document;
//     pdfx.PdfPage? page;
//     try {
//       document = await pdfx.PdfDocument.openFile(pdfFile.path);
      
//       if (pageNumber > document.pagesCount) {
//         throw Exception('Page number $pageNumber exceeds document page count');
//       }
      
//       page = await document.getPage(pageNumber);
//       final pageImage = await page.render(
//         width: thumbnailWidth,
//         height: thumbnailHeight,
//       );
      
//       if (pageImage == null) {
//         throw Exception('Failed to render page $pageNumber');
//       }
      
//       return pageImage.bytes;
//     } catch (e) {
//       debugPrint('Error generating single page thumbnail: $e');
//       rethrow;
//     } finally {
//       await page?.close();
//       await document?.close();
//     }
//   }
// }