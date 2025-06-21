import 'package:korean_language_app/shared/enums/image_display_type.dart';

class ImageDisplaySource {
  final ImageDisplayType type;
  final String? path;
  final String? url;

  ImageDisplaySource({
    required this.type,
    this.path,
    this.url,
  });
}