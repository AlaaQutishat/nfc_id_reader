# nfc_id_reader

A Flutter plugin for reading NFC-enabled IDs and ePassports.

## Features

- **MRZ Extraction**: Extract Machine Readable Zone (MRZ) data from an image using Google ML Kit.
- **NFC Scanning**: Read and extract data from NFC-enabled IDs and ePassports using the MRZ data as the key.
- **Cross-Platform**: Supports Android and iOS (requires iOS 13.0 or newer).

## What This Plugin Does

This plugin provides an easy-to-use API to perform a two-step process for reading electronic passports and NFC IDs:
1. **Visual Scan**: Extracts the Document Number, Date of Birth, and Expiry Date from a photo of the ID/Passport's Machine Readable Zone (MRZ).
2. **NFC Scan**: Uses the extracted MRZ information to authenticate with the NFC chip inside the document and reads the embedded demographic data and facial image.

## Getting Started

### Prerequisites

#### Android
- Add the NFC permission to your `AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.NFC" />
  ```

#### iOS
- Requires iOS 13.0 or later.
- Add the Near Field Communication capability to your Xcode project.
- Add the `NFCReaderUsageDescription` to your `Info.plist`:
  ```xml
  <key>NFCReaderUsageDescription</key>
  <string>This app requires NFC to scan ePassports and IDs.</string>
  ```
- Also, add the ISO7816 application identifiers for passports to your `Info.plist`:
  ```xml
  <key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
  <array>
      <string>A0000002471001</string>
  </array>
  ```

## Usage

### 1. Import the package
```dart
import 'package:nfc_id_reader/nfc_id_reader.dart';
```

### 2. Initialize the reader
```dart
final nfcIdReader = NfcIdReader();
```

### 3. Extract MRZ Data from an Image
First, capture or select an image of the passport/ID's Machine Readable Zone (MRZ). For ID cards, this is typically located on the **back of the card**. Then pass the file to the plugin.

```dart
import 'dart:io';

// Assume you have an image file of the back of the ID card from the camera or gallery
File imageFile = File('path/to/image.jpg');

try {
  MrzData mrzData = await nfcIdReader.extractMrz(imageFile);
  print('Document Number: ${mrzData.documentNumber}');
  print('Date of Birth: ${mrzData.dateOfBirth}');
  print('Expiry Date: ${mrzData.expiryDate}');
  
  // Proceed to scan NFC using the extracted MRZ data
} catch (e) {
  print('Failed to extract MRZ: $e');
}
```

### 4. Scan the NFC Chip
Using the `MrzData` extracted above, prompt the user to hold their device near the NFC chip on their document.

```dart
try {
  PassportData passportData = await nfcIdReader.scanNfc(mrzData);
  
  // You now have access to the data stored on the NFC chip!
  print('Scanned successfully! Result: $passportData');
} catch (e) {
  print('NFC Scan failed: $e');
}
```

### Stop Scanning
You can cancel an active NFC scan session at any time:
```dart
await nfcIdReader.stopScanning();
```

## Example
For a complete, working example, see the `example/` folder in the repository.

## Customization & Contributing
This plugin is fully open-source! If you need to edit the scanning UI design, tweak the native behavior, or add new features, feel free to clone or fork the repository on GitHub. You have full access to customize the code to fit your project's specific needs.
