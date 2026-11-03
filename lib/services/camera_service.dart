import 'dart:io';
import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  int _selectedCameraIndex = 0;

  bool get isInitialized => _isInitialized && _controller != null && _controller!.value.isInitialized;
  bool get isRecording => _isRecording;
  bool get isSimulated => _isSimulated;
  cam.CameraController? get controller => _controller;
  String? get errorMessage => _errorMessage;
  List<cam.CameraDescription> get availableCamerasList => _availableCameras;
  bool get isFrontCamera =>
      _availableCameras.isNotEmpty &&
      _availableCameras[_selectedCameraIndex].lensDirection == cam.CameraLensDirection.front;

  /// Initialize camera with requested lens direction (defaults to front for selfie teleprompting)
  Future<bool> initialize({bool preferFront = true}) async {
    _errorMessage = null;

    // Check permissions on mobile platforms
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final camStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (camStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
        _errorMessage = 'Camera and Microphone permissions are required to record video.';
        _isSimulated = true;
        return false;
      }
    }

    try {
      _availableCameras = await cam.availableCameras();
      if (_availableCameras.isEmpty) {
        _isSimulated = true;
        _isInitialized = true;
        return true;
      }

      // Pick front or back camera
      int targetIndex = 0;
      if (preferFront) {
        final frontIdx = _availableCameras.indexWhere(
          (c) => c.lensDirection == cam.CameraLensDirection.front,
        );
        if (frontIdx != -1) targetIndex = frontIdx;
      } else {
        final backIdx = _availableCameras.indexWhere(
          (c) => c.lensDirection == cam.CameraLensDirection.back,
        );
        if (backIdx != -1) targetIndex = backIdx;
      }

      _selectedCameraIndex = targetIndex;
      await _setupController(_availableCameras[_selectedCameraIndex]);
      _isInitialized = true;
      _isSimulated = false;
      return true;
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      _errorMessage = e.toString();
      _isSimulated = true;
      _isInitialized = true;
      return false;
    }
  }

  Future<void> _setupController(cam.CameraDescription description) async {
    final oldController = _controller;
    if (oldController != null) {
      await oldController.dispose();
    }

    final newController = cam.CameraController(
      description,
      cam.ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: cam.ImageFormatGroup.jpeg,
    );

    _controller = newController;
    await newController.initialize();
  }

  /// Switch between front and rear cameras
  Future<void> toggleCamera() async {
    if (_availableCameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _setupController(_availableCameras[_selectedCameraIndex]);
  }

  /// Start video recording
  Future<bool> startRecording() async {
    if (_isRecording) return true;

    if (_isSimulated || _controller == null || !_controller!.value.isInitialized) {
      _isRecording = true;
      return true;
    }

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

  /// Stop video recording and persist file
  Future<File?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;

    if (_isSimulated || _controller == null || !_controller!.value.isInitialized) {
      // In simulated mode, create a dummy placeholder file in documents
      try {
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${dir.path}/recorded_take_$timestamp.mp4');
        await file.writeAsString('Simulated Video Take at $timestamp');
        return file;
      } catch (_) {
        return null;
      }
    }

    try {
      final cam.XFile xFile = await _controller!.stopVideoRecording();
      final dir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${dir.path}/teleprompter_videos');
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '${videosDir.path}/take_$timestamp.mp4';
      final savedFile = await File(xFile.path).copy(targetPath);
      return savedFile;
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    _isRecording = false;
    _isInitialized = false;
    await _controller?.dispose();
    _controller = null;
  }
}
