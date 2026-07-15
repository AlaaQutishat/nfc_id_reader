import 'dart:typed_data';

class MrzData {
  final String documentNumber;
  final String dateOfBirth;
  final String expiryDate;

  MrzData({
    required this.documentNumber,
    required this.dateOfBirth,
    required this.expiryDate,
  });
}

class PassportData {
  final String? firstName;
  final String? lastName;
  final String? fullNameArabic;
  final String? motherName;
  final String? fatherName;
  final String? grandMotherName;
  final String? grandFatherName;
  final String? bloodType;
  final String? religion;
  final String? motherPlaceOfBirth;
  final String? fatherPlaceOfBirth;
  final String? placeOfBirth;
  final String? gender;
  final String? dateOfBirth;
  final String? nationality;
  final String? documentNumber;
  final String? personalNumber;
  final String? familyNumber;
  final String? expiryDate;
  final String? issuingState;
  final Uint8List? faceImage;
  final String? dg13RawString;

  PassportData({
    this.firstName,
    this.lastName,
    this.fullNameArabic,
    this.motherName,
    this.fatherName,
    this.grandMotherName,
    this.grandFatherName,
    this.bloodType,
    this.religion,
    this.motherPlaceOfBirth,
    this.fatherPlaceOfBirth,
    this.placeOfBirth,
    this.gender,
    this.dateOfBirth,
    this.nationality,
    this.documentNumber,
    this.personalNumber,
    this.familyNumber,
    this.expiryDate,
    this.issuingState,
    this.faceImage,
    this.dg13RawString,
  });

  factory PassportData.fromMap(Map<dynamic, dynamic> map) {
    return PassportData(
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      fullNameArabic: map['fullNameArabic'] as String?,
      motherName: map['motherName'] as String?,
      fatherName: map['fatherName'] as String?,
      grandMotherName: map['grandMotherName'] as String?,
      grandFatherName: map['grandFatherName'] as String?,
      bloodType: map['bloodType'] as String?,
      religion: map['religion'] as String?,
      motherPlaceOfBirth: map['motherPlaceOfBirth'] as String?,
      fatherPlaceOfBirth: map['fatherPlaceOfBirth'] as String?,
      placeOfBirth: map['placeOfBirth'] as String?,
      gender: map['gender'] as String?,
      dateOfBirth: map['dateOfBirth'] as String?,
      nationality: map['nationality'] as String?,
      documentNumber: map['documentNumber'] as String?,
      personalNumber: map['personalNumber'] as String?,
      familyNumber: map['familyNumber'] as String?,
      expiryDate: map['expiryDate'] as String?,
      issuingState: map['issuingState'] as String?,
      faceImage: map['faceImage'] as Uint8List?,
      dg13RawString: map['dg13RawString'] as String?,
    );
  }
}
