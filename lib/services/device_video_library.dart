import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/recorded_video.dart';

enum DeviceSaveOutcome { saved, permissionDenied, failed }

/// The phone's public video collection, where takes are kept outside the app:
/// visible in Gallery/Photos, reachable from a computer, and kept on uninstall.
abstract class DeviceVideoLibrary {
  static const String folderName = 'Cuevanta';

  /// Where takes end up, in words the user recognises.
  String get locationLabel;

  bool get isAvailable;

  /// Copies [take] into the public collection, leaving the app's own copy in place.
  Future<DeviceSaveOutcome> save(RecordedVideo take);

  factory DeviceVideoLibrary.forThisDevice() {
    if (kIsWeb) return const _UnavailableVideoLibrary();
    if (Platform.isAndroid) return AndroidMoviesFolder();
    if (Platform.isIOS) return const IosPhotosAlbum();
    return const _UnavailableVideoLibrary();
  }
}

/// Android: Movies/Cuevanta through MediaStore (see PublicVideoSaver.kt).
class AndroidMoviesFolder implements DeviceVideoLibrary {
  static const MethodChannel _channel = MethodChannel('cuevanta/public_videos');

  @override
  String get locationLabel => 'Movies/${DeviceVideoLibrary.folderName}';

  @override
  bool get isAvailable => true;

  @override
  Future<DeviceSaveOutcome> save(RecordedVideo take) async {
    final firstTry = await _copy(take);
    if (firstTry != DeviceSaveOutcome.permissionDenied) return firstTry;

    // Only Android 9 and older ask for this; newer versions never get here.
    final granted = await Permission.storage.request().isGranted;
    return granted ? _copy(take) : DeviceSaveOutcome.permissionDenied;
  }

  Future<DeviceSaveOutcome> _copy(RecordedVideo take) async {
    try {
      await _channel.invokeMethod<String>('saveVideo', {
        'path': take.filePath,
        'fileName': take.exportFileName,
      });
      return DeviceSaveOutcome.saved;
    } on PlatformException catch (error) {
      if (error.code == 'permission_denied') return DeviceSaveOutcome.permissionDenied;
      debugPrint('Could not save ${take.filePath} to Movies: ${error.message}');
      return DeviceSaveOutcome.failed;
    }
  }
}

/// iOS has no shared folders, so takes go to a "Cuevanta" album in Photos.
class IosPhotosAlbum implements DeviceVideoLibrary {
  const IosPhotosAlbum();

  @override
  String get locationLabel => 'Photos › ${DeviceVideoLibrary.folderName}';

  @override
  bool get isAvailable => true;

  @override
  Future<DeviceSaveOutcome> save(RecordedVideo take) async {
    if (!await Gal.requestAccess(toAlbum: true)) return DeviceSaveOutcome.permissionDenied;
    try {
      await Gal.putVideo(take.filePath, album: DeviceVideoLibrary.folderName);
      return DeviceSaveOutcome.saved;
    } on GalException catch (error) {
      debugPrint('Could not save ${take.filePath} to Photos: ${error.type.message}');
      return error.type == GalExceptionType.accessDenied
          ? DeviceSaveOutcome.permissionDenied
          : DeviceSaveOutcome.failed;
    }
  }
}

class _UnavailableVideoLibrary implements DeviceVideoLibrary {
  const _UnavailableVideoLibrary();

  @override
  String get locationLabel => '';

  @override
  bool get isAvailable => false;

  @override
  Future<DeviceSaveOutcome> save(RecordedVideo take) async => DeviceSaveOutcome.failed;
}
