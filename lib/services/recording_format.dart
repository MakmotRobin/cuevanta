import 'package:camera/camera.dart' as cam;
import '../models/teleprompter_settings.dart';

/// Camera settings for a [RecordingQuality], tuned for vertical social video.
///
/// Presets are landscape sizes from the sensor (1920×1080 for 1080p); with
/// capture locked to portrait the file comes out 1080×1920, i.e. 9:16.
class RecordingFormat {
  static const int framesPerSecond = 30;
  static const int audioBitrate = 128000;

  final cam.ResolutionPreset resolutionPreset;
  final int videoBitrate;

  const RecordingFormat._(this.resolutionPreset, this.videoBitrate);

  factory RecordingFormat.forQuality(RecordingQuality quality) => switch (quality) {
        RecordingQuality.hd720 => const RecordingFormat._(cam.ResolutionPreset.high, 6000000),
        RecordingQuality.fullHd1080 => const RecordingFormat._(cam.ResolutionPreset.veryHigh, 12000000),
        RecordingQuality.uhd4k => const RecordingFormat._(cam.ResolutionPreset.ultraHigh, 40000000),
      };
}
