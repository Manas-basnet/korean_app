import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_view/photo_view.dart';
import 'package:dismissible_page/dismissible_page.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

class DialogUtils {
  static void showFullScreenImage(
    BuildContext context, 
    String? imageUrl, 
    String? imagePath, {
    String? heroTag,
  }) {
    final snackBarCubit = context.read<SnackBarCubit>();
    final languageCubit = context.read<LanguagePreferenceCubit>();

    if ((imageUrl?.isEmpty ?? true) && (imagePath?.isEmpty ?? true)) {
      snackBarCubit.showErrorLocalized(
        korean: '이미지를 찾을 수 없습니다',
        english: 'Image not found',
      );
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _FullScreenImageViewer(
              imageUrl: imageUrl,
              imagePath: imagePath,
              heroTag: heroTag ?? (imageUrl ?? imagePath ?? 'image'),
              languageCubit: languageCubit,
            ),
          );
        },
      ),
    );
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final String? imageUrl;
  final String? imagePath;
  final String heroTag;
  final LanguagePreferenceCubit languageCubit;

  const _FullScreenImageViewer({
    required this.imageUrl,
    required this.imagePath,
    required this.heroTag,
    required this.languageCubit,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PhotoViewController _photoViewController;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _photoViewController = PhotoViewController();
  }

  @override
  void dispose() {
    _photoViewController.dispose();
    super.dispose();
  }

  void _handleScaleEnd(PhotoViewControllerValue controllerValue) {
    setState(() {
      // Consider it dragging/zoomed if scale is significantly different from 1.0
      _isDragging = (controllerValue.scale! - 1.0).abs() > 0.1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DismissiblePage(
      onDismissed: () => Navigator.of(context).pop(),
      direction: DismissiblePageDismissDirection.vertical,
      backgroundColor: Colors.black,
      dismissThresholds: const {
        DismissiblePageDismissDirection.vertical: 0.2,
      },
      dragSensitivity: _isDragging ? 0.1 : 1.0,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            PhotoView.customChild(
              controller: _photoViewController,
              onScaleEnd: (context, details, controllerValue) {
                _handleScaleEnd(controllerValue);
              },
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
              minScale: PhotoViewComputedScale.contained * 0.5,
              maxScale: PhotoViewComputedScale.covered * 4.0,
              initialScale: PhotoViewComputedScale.contained,
              heroAttributes: PhotoViewHeroAttributes(tag: widget.heroTag),
              enableRotation: false,
              child: CustomCachedImage(
                imageUrl: widget.imageUrl,
                imagePath: widget.imagePath,
                fit: BoxFit.contain,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 3,
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.broken_image_rounded,
                        size: 64,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.languageCubit.getLocalizedText(
                          korean: '이미지를 불러올 수 없습니다',
                          english: 'Cannot load image',
                        ),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Close button (backup for users who don't know about drag-to-dismiss)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    splashColor: Colors.white.withValues(alpha: 0.2),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
            
            // Subtle hint for gestures
            if (!_isDragging)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.languageCubit.getLocalizedText(
                        korean: '핀치로 확대 • 드래그하여 닫기',
                        english: 'Pinch to zoom • Drag to close',
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            
            // Reset zoom button when zoomed
            if (_isDragging)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 20,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: IconButton(
                      onPressed: () {
                        _photoViewController.reset();
                      },
                      icon: const Icon(
                        Icons.fullscreen_exit_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: widget.languageCubit.getLocalizedText(
                        korean: '원래 크기로',
                        english: 'Reset zoom',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:photo_view/photo_view.dart';
// import 'package:dismissible_page/dismissible_page.dart';
// import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
// import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
// import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

// class DialogUtils {
//   static void showFullScreenImage(
//     BuildContext context, 
//     String? imageUrl, 
//     String? imagePath, {
//     String? heroTag,
//   }) {
//     final snackBarCubit = context.read<SnackBarCubit>();
//     final languageCubit = context.read<LanguagePreferenceCubit>();

//     if ((imageUrl?.isEmpty ?? true) && (imagePath?.isEmpty ?? true)) {
//       snackBarCubit.showErrorLocalized(
//         korean: '이미지를 찾을 수 없습니다',
//         english: 'Image not found',
//       );
//       return;
//     }

//     Navigator.of(context).push(
//       PageRouteBuilder(
//         opaque: false,
//         barrierColor: Colors.black,
//         pageBuilder: (context, animation, secondaryAnimation) {
//           return FadeTransition(
//             opacity: animation,
//             child: _FullScreenImageViewer(
//               imageUrl: imageUrl,
//               imagePath: imagePath,
//               heroTag: heroTag ?? (imageUrl ?? imagePath ?? 'image'),
//               languageCubit: languageCubit,
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// class _FullScreenImageViewer extends StatelessWidget {
//   final String? imageUrl;
//   final String? imagePath;
//   final String heroTag;
//   final LanguagePreferenceCubit languageCubit;

//   const _FullScreenImageViewer({
//     required this.imageUrl,
//     required this.imagePath,
//     required this.heroTag,
//     required this.languageCubit,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return DismissiblePage(
//       onDismissed: () => Navigator.of(context).pop(),
//       direction: DismissiblePageDismissDirection.vertical,
//       backgroundColor: Colors.black,
//       dismissThresholds: const {
//         DismissiblePageDismissDirection.vertical: 0.15,
//       },
//       dragSensitivity: 0.8,
//       child: Scaffold(
//         backgroundColor: Colors.transparent,
//         body: Stack(
//           children: [
//             PhotoView.customChild(
//               backgroundDecoration: const BoxDecoration(
//                 color: Colors.black,
//               ),
//               minScale: PhotoViewComputedScale.contained * 0.8,
//               maxScale: PhotoViewComputedScale.covered * 3.0,
//               initialScale: PhotoViewComputedScale.contained,
//               heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
//               enableRotation: false,
//               // gaplessPlayback: true,
//               child: CustomCachedImage(
//                 imageUrl: imageUrl,
//                 imagePath: imagePath,
//                 fit: BoxFit.contain,
//                 placeholder: (context, url) => Center(
//                   child: CircularProgressIndicator(
//                     color: Theme.of(context).colorScheme.primary,
//                     strokeWidth: 3,
//                   ),
//                 ),
//                 errorWidget: (context, url, error) => Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const Icon(
//                         Icons.broken_image_rounded,
//                         size: 64,
//                         color: Colors.white54,
//                       ),
//                       const SizedBox(height: 16),
//                       Text(
//                         languageCubit.getLocalizedText(
//                           korean: '이미지를 불러올 수 없습니다',
//                           english: 'Cannot load image',
//                         ),
//                         style: const TextStyle(
//                           color: Colors.white54,
//                           fontSize: 16,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
            
//             // Close button (backup for users who don't know about drag-to-dismiss)
//             Positioned(
//               top: MediaQuery.of(context).padding.top + 16,
//               right: 20,
//               child: Material(
//                 color: Colors.transparent,
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.black.withValues(alpha: 0.5),
//                     shape: BoxShape.circle,
//                   ),
//                   child: IconButton(
//                     onPressed: () => Navigator.of(context).pop(),
//                     icon: const Icon(
//                       Icons.close_rounded,
//                       color: Colors.white,
//                       size: 24,
//                     ),
//                     splashColor: Colors.white.withValues(alpha: 0.2),
//                     highlightColor: Colors.white.withValues(alpha: 0.1),
//                   ),
//                 ),
//               ),
//             ),
            
//             // Subtle hint for drag-to-dismiss (optional)
//             Positioned(
//               bottom: MediaQuery.of(context).padding.bottom + 20,
//               left: 0,
//               right: 0,
//               child: Center(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withValues(alpha: 0.6),
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Text(
//                     languageCubit.getLocalizedText(
//                       korean: '위 아래로 드래그하여 닫기',
//                       english: 'Drag up or down to close',
//                     ),
//                     style: const TextStyle(
//                       color: Colors.white70,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }