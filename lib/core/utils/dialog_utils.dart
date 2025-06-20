import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

class DialogUtils {
  static void showFullScreenImage(BuildContext context, String? imageUrl, String? imagePath) {
    final snackBarCubit = context.read<SnackBarCubit>();
    final languageCubit = context.read<LanguagePreferenceCubit>();


    if ((imageUrl?.isEmpty ?? true) && (imagePath?.isEmpty ?? true)) {
      snackBarCubit.showErrorLocalized(
        korean: '이미지를 찾을 수 없습니다',
        english: 'Image not found',
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: CustomCachedImage(
                  imageUrl: imageUrl,
                  imagePath: imagePath,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
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
                          languageCubit.getLocalizedText(
                            korean: '이미지를 불러올 수 없습니다',
                            english: 'Cannot load image',
                          ),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}