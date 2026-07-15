import Flutter
import UIKit

public class NfcIdReaderPlugin: NSObject, FlutterPlugin {
  private var scanner: PassportScanner?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "nfc_id_reader", binaryMessenger: registrar.messenger())
    let instance = NfcIdReaderPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getPlatformVersion" {
      result("iOS " + UIDevice.current.systemVersion)
    } else if call.method == "startScanning" {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Arguments missing", details: nil))
            return
        }
        
        // Doc number and dates are required for MRZ
        let docNumber = args["docNumber"] as? String
        let dob = args["dob"] as? String
        let expiry = args["expiry"] as? String
        let can = args["can"] as? String
        
        self.scanner = PassportScanner()
        self.scanner?.scanPassport(docNumber: docNumber, birthDate: dob, expiryDate: expiry, can: can) { [weak self] scanResult in
            switch scanResult {
            case .success(let data):
                result(data)
            case .failure(let error):
                result(FlutterError(code: "SCAN_ERROR", message: error.localizedDescription, details: nil))
            }
            self?.scanner = nil 
        }

    } else if call.method == "stopScanning" {
        // iOS NFC dialog handles cancellation
        result("Stopped")
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}