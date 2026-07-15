import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'nfc_id_reader_method_channel.dart';

abstract class NfcIdReaderPluginPlatform extends PlatformInterface {
  /// Constructs a NfcIdReaderPluginPlatform.
  NfcIdReaderPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static NfcIdReaderPluginPlatform _instance = MethodChannelNfcIdReaderPlugin();

  /// The default instance of [NfcIdReaderPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelNfcIdReaderPlugin].
  static NfcIdReaderPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NfcIdReaderPluginPlatform] when
  /// they register themselves.
  static set instance(NfcIdReaderPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
