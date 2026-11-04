import 'dart:convert';
import 'package:flutter/material.dart';

enum ReadingGuideStyle {
  band, // Highlighted horizontal band
  line, // Horizontal marker line
  dimEdges, // Bright center, dimmed top & bottom
  none,
}

enum ScriptBoxArea {
  nearCameraTop, // Optimal for eye contact with phone selfie camera
  topHalf,
  floatingBox,
  fullscreen,
}

class TeleprompterSettings {
  double fontSize;
  double lineSpacing;
  double scrollSpeed; // pixels per second (typically 15 to 80)
  int countdownDuration; // 0, 3, 5, 10 seconds
  bool mirrorHorizontal; // Flip X for teleprompter glass
  bool mirrorVertical; // Flip Y
  bool showGuideLine;
  double guidePositionPercent; // 0.1 to 0.9 (default ~0.25 near top camera)
  ReadingGuideStyle guideStyle;
  TextAlign textAlign;
  Color textColor;
  Color backgroundColor;
  Color guideColor;
  double overlayOpacity; // 0.0 (transparent) to 0.95 (opaque) in camera mode
  double textHorizontalMargin; // Horizontal padding in % (e.g., 0.1 = 10% on each side)
  bool autoRecordVideo; // Trigger recording when countdown completes
  ScriptBoxArea boxArea;
  bool preferFrontCamera;
  bool enableHapticFeedback;
  bool followVoice; // scroll with the reader's speech instead of a fixed speed

  TeleprompterSettings({
    this.fontSize = 28.0,
    this.lineSpacing = 1.6,
    this.scrollSpeed = 38.0,
    this.countdownDuration = 3,
    this.mirrorHorizontal = false,
    this.mirrorVertical = false,
    this.showGuideLine = true,
    this.guidePositionPercent = 0.28, // Just under the camera lens!
    this.guideStyle = ReadingGuideStyle.band,
    this.textAlign = TextAlign.center,
    this.textColor = Colors.white,
    this.backgroundColor = const Color(0xDD000000),
    this.guideColor = const Color(0xFFCFB07A),
    this.overlayOpacity = 0.65,
    this.textHorizontalMargin = 24.0,
    this.autoRecordVideo = true,
    this.boxArea = ScriptBoxArea.nearCameraTop,
    this.preferFrontCamera = true,
    this.enableHapticFeedback = true,
    this.followVoice = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize,
      'lineSpacing': lineSpacing,
      'scrollSpeed': scrollSpeed,
      'countdownDuration': countdownDuration,
      'mirrorHorizontal': mirrorHorizontal,
      'mirrorVertical': mirrorVertical,
      'showGuideLine': showGuideLine,
      'guidePositionPercent': guidePositionPercent,
      'guideStyle': guideStyle.index,
      'textAlign': textAlign.index,
      'textColor': textColor.toARGB32(),
      'backgroundColor': backgroundColor.toARGB32(),
      'guideColor': guideColor.toARGB32(),
      'overlayOpacity': overlayOpacity,
      'textHorizontalMargin': textHorizontalMargin,
      'autoRecordVideo': autoRecordVideo,
      'boxArea': boxArea.index,
      'preferFrontCamera': preferFrontCamera,
      'enableHapticFeedback': enableHapticFeedback,
      'followVoice': followVoice,
    };
  }

  factory TeleprompterSettings.fromMap(Map<String, dynamic> map) {
    return TeleprompterSettings(
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 28.0,
      lineSpacing: (map['lineSpacing'] as num?)?.toDouble() ?? 1.6,
      scrollSpeed: (map['scrollSpeed'] as num?)?.toDouble() ?? 38.0,
      countdownDuration: map['countdownDuration'] as int? ?? 3,
      mirrorHorizontal: map['mirrorHorizontal'] as bool? ?? false,
      mirrorVertical: map['mirrorVertical'] as bool? ?? false,
      showGuideLine: map['showGuideLine'] as bool? ?? true,
      guidePositionPercent: (map['guidePositionPercent'] as num?)?.toDouble() ?? 0.28,
      guideStyle: ReadingGuideStyle.values[
          (map['guideStyle'] as int? ?? ReadingGuideStyle.band.index).clamp(0, ReadingGuideStyle.values.length - 1)],
      textAlign: TextAlign.values[
          (map['textAlign'] as int? ?? TextAlign.center.index).clamp(0, TextAlign.values.length - 1)],
      textColor: map['textColor'] != null ? Color(map['textColor'] as int) : Colors.white,
      backgroundColor: map['backgroundColor'] != null ? Color(map['backgroundColor'] as int) : const Color(0xDD000000),
      guideColor: map['guideColor'] != null ? Color(map['guideColor'] as int) : const Color(0xFFCFB07A),
      overlayOpacity: (map['overlayOpacity'] as num?)?.toDouble() ?? 0.65,
      textHorizontalMargin: (map['textHorizontalMargin'] as num?)?.toDouble() ?? 24.0,
      autoRecordVideo: map['autoRecordVideo'] as bool? ?? true,
      boxArea: ScriptBoxArea.values[
          (map['boxArea'] as int? ?? ScriptBoxArea.nearCameraTop.index).clamp(0, ScriptBoxArea.values.length - 1)],
      preferFrontCamera: map['preferFrontCamera'] as bool? ?? true,
      enableHapticFeedback: map['enableHapticFeedback'] as bool? ?? true,
      followVoice: map['followVoice'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory TeleprompterSettings.fromJson(String source) =>
      TeleprompterSettings.fromMap(json.decode(source));

  TeleprompterSettings copyWith({
    double? fontSize,
    double? lineSpacing,
    double? scrollSpeed,
    int? countdownDuration,
    bool? mirrorHorizontal,
    bool? mirrorVertical,
    bool? showGuideLine,
    double? guidePositionPercent,
    ReadingGuideStyle? guideStyle,
    TextAlign? textAlign,
    Color? textColor,
    Color? backgroundColor,
    Color? guideColor,
    double? overlayOpacity,
    double? textHorizontalMargin,
    bool? autoRecordVideo,
    ScriptBoxArea? boxArea,
    bool? preferFrontCamera,
    bool? enableHapticFeedback,
    bool? followVoice,
  }) {
    return TeleprompterSettings(
      fontSize: fontSize ?? this.fontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      countdownDuration: countdownDuration ?? this.countdownDuration,
      mirrorHorizontal: mirrorHorizontal ?? this.mirrorHorizontal,
      mirrorVertical: mirrorVertical ?? this.mirrorVertical,
      showGuideLine: showGuideLine ?? this.showGuideLine,
      guidePositionPercent: guidePositionPercent ?? this.guidePositionPercent,
      guideStyle: guideStyle ?? this.guideStyle,
      textAlign: textAlign ?? this.textAlign,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      guideColor: guideColor ?? this.guideColor,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      textHorizontalMargin: textHorizontalMargin ?? this.textHorizontalMargin,
      autoRecordVideo: autoRecordVideo ?? this.autoRecordVideo,
      boxArea: boxArea ?? this.boxArea,
      preferFrontCamera: preferFrontCamera ?? this.preferFrontCamera,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      followVoice: followVoice ?? this.followVoice,
    );
  }
}
