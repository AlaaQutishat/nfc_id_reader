import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'models.dart';
import 'mrz_helper.dart';

export 'models.dart';

class NfcIdReader {
  static const MethodChannel _channel = MethodChannel('nfc_id_reader');

  Future<String?> getPlatformVersion() async {
    final version = await _channel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  /// Extracts MRZ data from the provided image file.
  ///
  /// Returns [MrzData] if successful, or throws an exception if
  /// extraction fails or data is invalid.
  Future<MrzData> extractMrz(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer();

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      final mrzMap = MrzHelper.extractMRZ(recognizedText);

      if (mrzMap == null || !MrzHelper.validateMRZ(mrzMap)) {
        throw Exception("Could not extract valid MRZ data from the image.");
      }

      return MrzData(
        documentNumber: mrzMap['docNumber']!,
        dateOfBirth: mrzMap['dob']!,
        expiryDate: mrzMap['expiry']!,
      );
    } finally {
      textRecognizer.close();
    }
  }

  /// Starts the NFC scan session using the provided MRZ data.
  ///
  /// Returns [PassportData] on success.
  Future<PassportData> scanNfc(MrzData mrzData) async {
    try {
      final Map<String, dynamic> args = {
        'docNumber': mrzData.documentNumber,
        'dob': mrzData.dateOfBirth,
        'expiry': mrzData.expiryDate,
      };

      final dynamic result = await _channel.invokeMethod('startScanning', args);

      if (result is Map) {
        return PassportData.fromMap(result);
      } else {
        throw Exception("Invalid result format from native scan");
      }
    } on PlatformException catch (e) {
      throw Exception("Scan failed: ${e.message}");
    }
  }

  /// Stops any active scanning session.
  Future<void> stopScanning() async {
    await _channel.invokeMethod('stopScanning');
  }
}
