import 'package:flutter/services.dart';

/// Portrait for selfie video, landscape for glass prompter rigs.
const List<DeviceOrientation> allAppOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// The recording studio films vertical 9:16, so the screen stays upright.
const List<DeviceOrientation> studioOrientations = [DeviceOrientation.portraitUp];
