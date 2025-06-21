import 'package:korean_language_app/shared/enums/audio_display_type.dart';

class AudioDisplaySource {
  final AudioDisplayType type;
  final String? path;
  final String? url;

  AudioDisplaySource({
    required this.type,
    this.path,
    this.url,
  });
}