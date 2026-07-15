import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'nfc_id_reader_platform_interface.dart';

/// An implementation of [NfcIdReaderPluginPlatform] that uses method channels.
class MethodChannelNfcIdReaderPlugin extends NfcIdReaderPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('nfc_id_reader');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
