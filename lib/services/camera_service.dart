import 'dart:io';
import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/teleprompter_settings.dart';
import 'recording_format.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  List<cam.CameraDescription> _availableCameras = [];
  cam.CameraController? _controller;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isSimulated = false; // Fallback for emulator / environments without physical cameras
  String? _errorMessage;
  bool _isPermissionDenied = false;
  int _selectedCameraIndex = 0;
  static const String _takesFolderName = 'teleprompter_videos';
  RecordingFormat _format = RecordingFormat.forQuality(RecordingQuality.fullHd1080);

  bool get isInitialized => _isInitialized && _controller != null && _controller!.value.isInitialized;
  bool get isRecording => _isRecording;
  bool get isSimulated => _isSimulated;
  cam.CameraController? get controller => _controller;
  String? get errorMessage => _errorMessage;
  bool get isPermissionDenied => _isPermissionDenied;
  bool get canSwitchCamera => _availableCameras.length > 1;
  List<cam.CameraDescription> get availableCamerasList => _availableCameras;
  bool get isFrontCamera =>
      _availableCameras.isNotEmpty &&
      _availableCameras[_selectedCameraIndex].lensDirection == cam.CameraLensDirection.front;

  /// Opens the front (or back) camera for vertical recording at [quality].
  Future<bool> initialize({
    bool preferFront = true,
    RecordingQuality quality = RecordingQuality.fullHd1080,
  }) async {
    _errorMessage = null;
    _format = RecordingFormat.forQuality(quality);
    _isPermissionDenied = false;

    if (!await _requestCapturePermissions()) {
      _errorMessage = 'Camera and microphone access is needed to record video.';
      _isPermissionDenied = true;
      _isSimulated = true;
      _isInitialized = true;
      return false;
    }

    try {
      _availableCameras = await cam.availableCameras();
      if (_availableCameras.isEmpty) {
        _errorMessage = 'No camera found on this device.';
        _isSimulated = true;
        _isInitialized = true;
        return true;
      }

      _selectedCameraIndex = _cameraIndexFacing(
        preferFront ? cam.CameraLensDirection.front : cam.CameraLensDirection.back,
      );
      await _setupController(_availableCameras[_selectedCameraIndex]);
      _isInitialized = true;
      _isSimulated = false;
      return true;
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      _errorMessage = 'Camera unavailable on this device.';
      _isSimulated = true;
      _isInitialized = true;
      return false;
    }
  }

  /// Index of the first camera facing [direction], or the first camera if none does.
  int _cameraIndexFacing(cam.CameraLensDirection direction) {
    final index = _availableCameras.indexWhere((c) => c.lensDirection == direction);
    return index == -1 ? 0 : index;
  }

  /// Returns true when camera + microphone may be used (always true off mobile).
  Future<bool> _requestCapturePermissions() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return true;
    final statuses = await [Permission.camera, Permission.microphone].request();
    return statuses.values.every((status) => status.isGranted || status.isLimited);
  }

  Future<void> openPermissionSettings() => openAppSettings();

  Future<void> _setupController(cam.CameraDescription description) async {
    final oldController = _controller;
    if (oldController != null) {
      await oldController.dispose();
    }

    final newController = cam.CameraController(
      description,
      _format.resolutionPreset,
      enableAudio: true,
      fps: RecordingFormat.framesPerSecond,
      videoBitrate: _format.videoBitrate,
      audioBitrate: RecordingFormat.audioBitrate,
      imageFormatGroup: cam.ImageFormatGroup.jpeg,
    );

    _controller = newController;
    await newController.initialize();
    await _lockVerticalCapture(newController);
  }

  /// Keeps takes 9:16 even if the phone is tilted while recording.
  Future<void> _lockVerticalCapture(cam.CameraController controller) async {
    try {
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } on cam.CameraException catch (error) {
      debugPrint('Capture orientation lock unsupported here: ${error.description}');
    }
  }

  /// Switch between front and rear cameras
  Future<void> toggleCamera() async {
    if (!canSwitchCamera || _isRecording) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _setupController(_availableCameras[_selectedCameraIndex]);
  }

  /// Start video recording. Returns false when no real camera is available.
  Future<bool> startRecording() async {
    if (_isRecording) return true;
    if (_isSimulated || !isInitialized) return false;

    try {
      await _controller!.startVideoRecording();
      _isRecording = true;
      return true;
    } catch (e) {
      debugPrint('Error starting video recording: $e');
      return false;
    }
  }

  /// Pause video recording
  Future<void> pauseRecording() async {
    if (!_isRecording) return;
    if (_controller != null && _controller!.value.isRecordingVideo) {
      await _controller!.pauseVideoRecording();
    }
  }

  /// Resume video recording
  Future<void> resumeRecording() async {
    if (!_isRecording) return;
    if (_controller != null && _controller!.value.isRecordingPaused) {
      await _controller!.resumeVideoRecording();
    }
  }

  /// Stops recording and moves the take into the app's videos folder as [fileName].
  Future<File?> stopRecording({required String fileName}) async {
    if (!_isRecording) return null;
    _isRecording = false;
    if (!isInitialized) return null;

    try {
      final recorded = await _controller!.stopVideoRecording();
      final target = await _uniqueTakePath(fileName);
      return await _moveFile(File(recorded.path), target);
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      return null;
    }
  }

  /// Path in the takes folder for [fileName], numbered "(2)", "(3)"… if taken.
  Future<String> _uniqueTakePath(String fileName) async {
    final documents = await getApplicationDocumentsDirectory();
    final videosDir = Directory('${documents.path}/$_takesFolderName');
    if (!await videosDir.exists()) await videosDir.create(recursive: true);

    final dot = fileName.lastIndexOf('.');
    final stem = dot < 0 ? fileName : fileName.substring(0, dot);
    final extension = dot < 0 ? '' : fileName.substring(dot);
    var candidate = '${videosDir.path}/$fileName';
    for (var copy = 2; await File(candidate).exists(); copy++) {
      candidate = '${videosDir.path}/$stem ($copy)$extension';
    }
    return candidate;
  }

  /// Renames when possible (no second copy on disk); copies and deletes across volumes.
  static Future<File> _moveFile(File source, String targetPath) async {
    try {
      return await source.rename(targetPath);
    } on FileSystemException {
      final copied = await source.copy(targetPath);
      await source.delete();
      return copied;
    }
  }

  Future<void> dispose() async {
    _isRecording = false;
    _isInitialized = false;
    await _controller?.dispose();
    _controller = null;
  }
}
