import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nfc_id_reader/nfc_id_reader.dart';

class ScanningResult {
  final MrzData mrzData;
  final String imagePath;

  ScanningResult({required this.mrzData, required this.imagePath});
}

class IdReaderService {
  final NfcIdReader _nfcIdReader = NfcIdReader();
  final ImagePicker _picker = ImagePicker();

  /// Picks an image from the camera, requests permissions, and extracts MRZ data.
  Future<ScanningResult> pickIdImage() async {
    // Request camera permission explicitly
    final status = await Permission.camera.request();

    if (status.isPermanentlyDenied) {
      throw const FileSystemException(
        'Camera permission is permanently denied. Please enable it in settings.',
      );
    }

    if (!status.isGranted) {
      throw const FileSystemException(
        'Camera permission is required to scan ID.',
      );
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) {
      throw const FileSystemException('No image captured.');
    }

    final capturedFile = File(image.path);

    // Use SDK to extract MRZ
    try {
      final mrzData = await _nfcIdReader.extractMrz(capturedFile);
      return ScanningResult(mrzData: mrzData, imagePath: image.path);
    } catch (e) {
      // Re-throw SDK errors which are usually friendly
      rethrow;
    }
  }

  /// Performs NFC scan using the provided MRZ data.
  Future<PassportData> scanNfc(MrzData mrzData) async {
    try {
      final data = await _nfcIdReader.scanNfc(mrzData);
      return data;
    } catch (e) {
      rethrow;
    }
  }

  /// Stops any ongoing NFC scanning.
  void stopScanning() {
    _nfcIdReader.stopScanning();
  }
}
