import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nfc_id_reader/nfc_id_reader.dart';
import 'services/id_reader_service.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _docNumController = TextEditingController();
  final _dobController = TextEditingController(); // YYMMDD
  final _expiryController = TextEditingController(); // YYMMDD

  final IdReaderService _idReaderService = IdReaderService();

  bool _isScanning = false;
  bool _isProcessingImage = false;
  String? _statusMessage;
  File? _capturedImage;

  @override
  void dispose() {
    _docNumController.dispose();
    _dobController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _startNfcScan() async {
    setState(() {
      _isScanning = true;
      _statusMessage = "Ready to scan. Hold card to back of phone.";
    });

    try {
      final docNum = _docNumController.text.trim();
      final dob = _dobController.text.trim();
      final expiry = _expiryController.text.trim();

      if (docNum.isEmpty || dob.length != 6 || expiry.length != 6) {
        throw Exception(
          "Please enter valid MRZ details (Dates in YYMMDD format)",
        );
      }

      final mrzData = MrzData(
        documentNumber: docNum,
        dateOfBirth: dob,
        expiryDate: expiry,
      );

      final data = await _idReaderService.scanNfc(mrzData);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(passportData: data)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    // Check for permanently denied permission first to show custom dialog
    final status = await Permission.camera.status;
    if (status.isPermanentlyDenied) {
      if (mounted) _showPermissionSettingsDialog();
      return;
    }

    try {
      setState(() {
        _isProcessingImage = true;
      });

      final result = await _idReaderService.pickIdImage();

      if (!mounted) return;

      setState(() {
        _docNumController.text = result.mrzData.documentNumber;
        _dobController.text = result.mrzData.dateOfBirth;
        _expiryController.text = result.mrzData.expiryDate;
        _capturedImage = File(result.imagePath);
      });

      // Auto-start NFC scan
      _startNfcScan();
    } catch (e) {
      if (mounted) {
        // If it's a "No image captured" exception, we can ignore it or show a message
        if (e is FileSystemException &&
            e.message.contains('No image captured')) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
      }
    }
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'Camera access is needed to scan ID cards. Please enable it in the system settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("NFC ID Reader")),
      body: _isScanning ? _buildScanningUI() : _buildFormUI(),
    );
  }

  Widget _buildScanningUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            _statusMessage ?? "Scanning...",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              _idReaderService.stopScanning();
              setState(() => _isScanning = false);
            },
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Widget _buildFormUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_isProcessingImage)
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: CircularProgressIndicator(),
            ),

          if (_capturedImage != null) ...[
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_capturedImage!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 20),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessingImage ? null : _pickImage,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                _capturedImage == null
                    ? "Take Photo of ID Back"
                    : "Retake Photo",
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _docNumController,
            decoration: const InputDecoration(
              labelText: "Document Number",
              border: OutlineInputBorder(),
              helperText: "Found on the back of ID (part of MRZ)",
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _dobController,
            decoration: const InputDecoration(
              labelText: "Date of Birth (YYMMDD)",
              border: OutlineInputBorder(),
              hintText: "800101",
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _expiryController,
            decoration: const InputDecoration(
              labelText: "Expiry Date (YYMMDD)",
              border: OutlineInputBorder(),
              hintText: "250101",
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessingImage ? null : _startNfcScan,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("Start NFC Scan"),
            ),
          ),
        ],
      ),
    );
  }
}
