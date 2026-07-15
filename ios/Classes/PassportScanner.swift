import Foundation
import NFCPassportReader
import UIKit
import Flutter

class PassportScanner {
    private var passportReader: PassportReader?
    
    func scanPassport(
        docNumber: String?,
        birthDate: String?, // YYMMDD
        expiryDate: String?, // YYMMDD
        can: String?,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        self.passportReader = PassportReader()
        
        // Log levels
        Log.logLevel = .debug
        Log.storeLogs = true
        
        if let docNum = docNumber, let dob = birthDate, let doe = expiryDate {
            print("NFC Scanner: Starting scan with MRZ details")
            if let canValue = can, !canValue.isEmpty {
                print("NFC Scanner: CAN provided (\(canValue)) but PACE/CAN is not directly supported by this library version. Proceeding with MRZ.")
            }
            
            let mrzKey = Util.getMRZKey(
                passportNumber: docNum,
                dateOfBirth: dob,
                dateOfExpiry: doe
            )
            self.passportReader?.readPassport(mrzKey: mrzKey) { [weak self] passport, error in
                self?.handleScanResult(passport: passport, error: error, completion: completion)
                self?.passportReader = nil
            }
        } else if let canValue = can, !canValue.isEmpty {
            // If only CAN is provided, we might need a different library or version.
            self.passportReader = nil
            completion(.failure(NSError(domain: "PassportScanner", code: -1, userInfo: [NSLocalizedDescriptionKey: "PACE/CAN scanning is not supported by the current library version. Please use MRZ details (Doc Number, DOB, Expiry)."])))
        } else {
            self.passportReader = nil
            completion(.failure(NSError(domain: "PassportScanner", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing scanning parameters (MRZ details required)"])))
        }
    }

    private func handleScanResult(passport: NFCPassportModel?, error: NFCPassportReaderError?, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        if let error = error {
            var errorMsg = error.localizedDescription
            
            // Map common errors to user friendly messages
            if errorMsg.contains("Invalid MRZ") || errorMsg.contains("BAC") || errorMsg.contains("PACE") {
                errorMsg = "Authentication failed. Likely incorrect ID details. Ensure the document number from the MRZ is correct."
            } else if errorMsg.contains("connection") || errorMsg.contains("Tag") {
                errorMsg = "NFC Connection lost. Please hold the card steady against the top-back of your phone."
            }
            
            print("NFC Scanner: Scan failed with error: \(errorMsg)")
            completion(.failure(NSError(domain: "PassportScanner", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
            return
        }
        
        guard let passport = passport else {
            print("NFC Scanner: Scan completed but no passport data found")
            completion(.failure(NSError(domain: "PassportScanner", code: -1, userInfo: [NSLocalizedDescriptionKey: "No passport data found"])))
            return
        }
        
        print("NFC Scanner: Scan successful for \(passport.firstName) \(passport.lastName)")
        var result: [String: Any] = [:]
        
        // DG1
        result["firstName"] = passport.firstName
        result["lastName"] = passport.lastName
        result["gender"] = passport.gender
        result["dateOfBirth"] = passport.dateOfBirth
        result["nationality"] = passport.nationality
        result["documentNumber"] = passport.documentNumber
        result["expiryDate"] = passport.documentExpiryDate
        result["issuingState"] = passport.issuingAuthority
        
        // DG2 (Face Image)
        if let image = passport.passportImage,
           let jpegData = image.jpegData(compressionQuality: 1.0) {
            result["faceImage"] = FlutterStandardTypedData(bytes: jpegData)
        }
        
        completion(.success(result))
    }
}
class Util {
    static func getMRZKey(passportNumber: String, dateOfBirth: String, dateOfExpiry: String) -> String {
        let docNum = passportNumber.trimmingCharacters(in: .whitespaces).uppercased()
        let dob = pad(dateOfBirth, toLength: 6)
        let doe = pad(dateOfExpiry, toLength: 6)
        
        let docNumChecksum = calculateCheckDigit(docNum)
        let dobChecksum = calculateCheckDigit(dob)
        let doeChecksum = calculateCheckDigit(doe)
        
        // NFCPassportReader expects a specific BAC key string.
        // For TD1, it is usually 24 chars (9+1+6+1+6+1).
        // If we have 12 digits, we'll try to use them all, but it might not be standard BAC.
        let mrzKey = "\(docNum)\(docNumChecksum)\(dob)\(dobChecksum)\(doe)\(doeChecksum)"
        
        if docNum.count == 12 {
            print("NFC Scanner: WARNING - Using 12-digit National ID. If authentication fails, please use the 9-character 'Access Number' instead.")
        }
        
        print("NFC Scanner: Generated MRZ Key (length \(mrzKey.count)): \(maskString(docNum))\(docNumChecksum)...")
        return mrzKey
    }
    
    private static func maskString(_ s: String) -> String {
        if s.count <= 3 { return s }
        return String(s.prefix(3)) + String(repeating: "*", count: s.count - 3)
    }
    
    private static func pad(_ string: String, toLength length: Int) -> String {
        var s = string
        while s.count < length {
            s += "<"
        }
        if s.count > length {
            s = String(s.prefix(length))
        }
        return s
    }
    
    private static func calculateCheckDigit(_ string: String) -> Int {
        let map: [Character: Int] = [
            "<": 0, "0": 0, "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9,
            "A": 10, "B": 11, "C": 12, "D": 13, "E": 14, "F": 15, "G": 16, "H": 17, "I": 18, "J": 19,
            "K": 20, "L": 21, "M": 22, "N": 23, "O": 24, "P": 25, "Q": 26, "R": 27, "S": 28, "T": 29,
            "U": 30, "V": 31, "W": 32, "X": 33, "Y": 34, "Z": 35
        ]
        
        let weights = [7, 3, 1]
        var total = 0
        
        for (index, char) in string.uppercased().enumerated() {
            let value = map[char] ?? 0
            let weight = weights[index % 3]
            total += value * weight
        }
        
        return total % 10
    }
}