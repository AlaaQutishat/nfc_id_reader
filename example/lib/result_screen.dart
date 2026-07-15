import 'package:flutter/material.dart';
import 'package:nfc_id_reader/nfc_id_reader.dart';

class ResultScreen extends StatelessWidget {
  final PassportData passportData;

  const ResultScreen({super.key, required this.passportData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ID Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (passportData.faceImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  passportData.faceImage!,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              )
            else
              const Icon(Icons.person, size: 100, color: Colors.grey),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildRow("First Name", passportData.firstName),
                    _buildRow("Last Name", passportData.lastName),
                    if (passportData.fullNameArabic != null &&
                        passportData.fullNameArabic!.isNotEmpty)
                      _buildRow("Full Name (Ar)", passportData.fullNameArabic),
                    if (passportData.motherName != null &&
                        passportData.motherName!.isNotEmpty)
                      _buildRow("Mother Name", passportData.motherName),
                    if (passportData.fatherName != null &&
                        passportData.fatherName!.isNotEmpty)
                      _buildRow("Father Name", passportData.fatherName),
                    if (passportData.grandMotherName != null &&
                        passportData.grandMotherName!.isNotEmpty)
                      _buildRow(
                        "GrandMother Name",
                        passportData.grandMotherName,
                      ),
                    if (passportData.grandFatherName != null &&
                        passportData.grandFatherName!.isNotEmpty)
                      _buildRow(
                        "Grandfather Name",
                        passportData.grandFatherName,
                      ),
                    if (passportData.religion != null &&
                        passportData.religion!.isNotEmpty)
                      _buildRow("Religion", passportData.religion),
                    if (passportData.bloodType != null &&
                        passportData.bloodType!.isNotEmpty)
                      _buildRow("Blood Type", passportData.bloodType),
                    if (passportData.motherPlaceOfBirth != null &&
                        passportData.motherPlaceOfBirth!.isNotEmpty)
                      _buildRow(
                        "Mother Birthplace",
                        passportData.motherPlaceOfBirth,
                      ),
                    if (passportData.fatherPlaceOfBirth != null &&
                        passportData.fatherPlaceOfBirth!.isNotEmpty)
                      _buildRow(
                        "Father Birthplace",
                        passportData.fatherPlaceOfBirth,
                      ),
                    if (passportData.placeOfBirth != null &&
                        passportData.placeOfBirth!.isNotEmpty)
                      _buildRow("Place of Birth", passportData.placeOfBirth),
                    _buildRow("Gender", passportData.gender),
                    _buildRow("Nationality", passportData.nationality),
                    _buildRow("Date of Birth", passportData.dateOfBirth),
                    const Divider(),
                    _buildRow("Doc Number", passportData.documentNumber),
                    _buildRow("Expiry Date", passportData.expiryDate),
                    _buildRow("Issuing State", passportData.issuingState),
                    if (passportData.dg13RawString != null &&
                        passportData.dg13RawString!.isNotEmpty) ...[
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "DG13 Raw String",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Text(
                        passportData.dg13RawString!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value ?? "N/A")),
        ],
      ),
    );
  }
}
