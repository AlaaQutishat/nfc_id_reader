package com.example.nfc_id_reader

import android.nfc.Tag
import android.nfc.tech.IsoDep
import org.jmrtd.BACKey
import org.jmrtd.PACEKeySpec
import org.jmrtd.PassportService
import org.jmrtd.lds.CardAccessFile
import org.jmrtd.lds.PACEInfo
import org.jmrtd.lds.icao.DG1File
import org.jmrtd.lds.icao.DG2File
import org.jmrtd.lds.iso19794.FaceImageInfo
import net.sf.scuba.smartcards.CardService
import java.io.InputStream
import java.util.*

class PassportReader(private val tag: Tag) {

    fun readPassport(docNumber: String?, dob: String?, expiry: String?, can: String?): Map<String, Any?> {
        val isoDep = IsoDep.get(tag)
        isoDep.timeout = 10000
        val cardService = CardService.getInstance(isoDep)
        val service = PassportService(cardService, 223, 223, false, true)
        service.open()

        val docNumVariations = mutableListOf<String>()
        if (docNumber != null) {
            var paddedDocNumber = docNumber
            if (paddedDocNumber.length < 9) {
                paddedDocNumber = paddedDocNumber.padEnd(9, '<')
            }
            // 1. Padded to 9 chars (Strict ICAO standard)
            docNumVariations.add(paddedDocNumber)
            
            // 2. Exact user/scanner input if different
            if (paddedDocNumber != docNumber) {
                docNumVariations.add(docNumber)
            }
        }

        var paceSucceeded = false
        try {
            val cardAccessFile = CardAccessFile(service.getInputStream(PassportService.EF_CARD_ACCESS))
            val securityInfos = cardAccessFile.securityInfos
            for (info in securityInfos) {
                if (info is PACEInfo) {
                    if (can != null && can.isNotEmpty()) {
                        try {
                            service.doPACE(PACEKeySpec.createCANKey(can), info.objectIdentifier, PACEInfo.toParameterSpec(info.parameterId), info.parameterId)
                            paceSucceeded = true
                            break
                        } catch (e: Exception) {
                            System.err.println("PACE CAN failed: ${e.message}")
                        }
                    }
                    
                    if (!paceSucceeded && dob != null && expiry != null) {
                        for (variation in docNumVariations) {
                            try {
                                val bacKey = BACKey(variation, dob, expiry)
                                service.doPACE(PACEKeySpec.createMRZKey(bacKey), info.objectIdentifier, PACEInfo.toParameterSpec(info.parameterId), info.parameterId)
                                paceSucceeded = true
                                System.out.println("PACE MRZ succeeded with variation: $variation")
                                break // Break variation loop
                            } catch (e: Exception) {
                                System.err.println("PACE MRZ variation $variation failed: ${e.message}")
                            }
                        }
                        if (paceSucceeded) break // Break securityInfos loop
                    }
                }
            }
        } catch (e: Exception) {
            System.err.println("CardAccessFile reading failed: ${e.message}")
        }

        if (!paceSucceeded && dob != null && expiry != null) {
            for (variation in docNumVariations) {
                try {
                    val bacKey = BACKey(variation, dob, expiry)
                    service.doBAC(bacKey)
                    paceSucceeded = true // Reusing boolean just as an auth success flag
                    System.out.println("BAC succeeded with variation: $variation")
                    break // Authentication succeeded, break variation loop
                } catch (bacException: Exception) {
                    System.err.println("BAC variation $variation failed: ${bacException.message}")
                }
            }
        }

        val result = mutableMapOf<String, Any?>()

        // Some modern chips require explicitly selecting the MRTD application again 
        // after PACE/BAC before reading the data groups, otherwise they return 0x6A82.
        try {
            service.sendSelectApplet(paceSucceeded)
        } catch (e: Exception) {
            System.err.println("Failed to select MRTD applet: ${e.message}")
        }

        // Read DG1
        try {
            val dg1In = service.getInputStream(PassportService.EF_DG1)
            val dg1File = DG1File(dg1In)
            val mrzInfo = dg1File.mrzInfo
            result["firstName"] = mrzInfo.secondaryIdentifier.replace("<", " ").trim()
            result["lastName"] = mrzInfo.primaryIdentifier.replace("<", " ").trim()
            result["gender"] = mrzInfo.gender.name.take(1) // Truncate "MALE" to "M", "FEMALE" to "F"
            result["dateOfBirth"] = mrzInfo.dateOfBirth
            result["nationality"] = mrzInfo.nationality
            result["documentNumber"] = mrzInfo.documentNumber
            result["personalNumber"] = mrzInfo.personalNumber
            result["expiryDate"] = mrzInfo.dateOfExpiry
            result["issuingState"] = mrzInfo.issuingState
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Read DG11 (For Localized Names like Arabic Full Name)
        try {
            val dg11In = service.getInputStream(PassportService.EF_DG11)
            val dg11File = org.jmrtd.lds.icao.DG11File(dg11In)
            
            val arabicName = dg11File.nameOfHolder
            if (arabicName != null && arabicName.isNotEmpty()) {
                val cleanArabicName = arabicName.replace("<", " ").trim()
                result["fullNameArabic"] = cleanArabicName
                
                // Usually the Full Name might consist of 3 or 4 parts depending on the ID
                val nameParts = cleanArabicName.split(" ")
                if (nameParts.size >= 2) {
                    result["fatherName"] = nameParts[1] // 2nd part is father
                }
                if (nameParts.size >= 3) {
                    result["grandFatherName"] = nameParts[2] // 3rd part is usually grandfather
                }
            }
            
            // Mother's name and GrandMother name are stored in otherNames, e.g., "[شريفه<جواد]"
            val otherNames = dg11File.otherNames
            if (otherNames != null && otherNames.isNotEmpty()) {
                // Remove brackets
                val rawOther = otherNames[0].replace("[", "").replace("]", "")
                val parts = rawOther.split("<")
                if (parts.isNotEmpty()) {
                    result["motherName"] = parts[0].trim()
                    if (parts.size >= 2 && parts[1].isNotBlank()) {
                        result["grandMotherName"] = parts[1].trim()
                    }
                }
            }
            
            try {
                val placeOfBirthList = dg11File.placeOfBirth
                if (placeOfBirthList != null && placeOfBirthList.isNotEmpty()) {
                    result["placeOfBirth"] = placeOfBirthList.joinToString(", ").replace("<", " ").trim()
                }
            } catch (e: Exception) {
                // ignore
            }
        } catch (e: Exception) {
            System.err.println("DG11 not found or parsing failed: ${e.message}")
        }

        // Try reading DG13 (Optional details, usually local country specific, e.g., Religion, Blood Type)
        try {
            val dg13In = service.getInputStream(PassportService.EF_DG13)
            val dg13Bytes = dg13In.readBytes()
            val dg13String = String(dg13Bytes, Charsets.UTF_8)
            result["dg13RawString"] = dg13String
            
            // Format is usually: "Key/KeyKurdish=Value ; Key2=Value2"
            val parts = dg13String.split(" ; ")
            for (part in parts) {
                if (part.contains("=")) {
                    val kv = part.split("=")
                    val keyStr = kv[0]
                    val valueStr = kv[1]
                    
                    if (keyStr.contains("الديانة", ignoreCase = true)) {
                        result["religion"] = valueStr
                    } else if (keyStr.contains("فئة الدم", ignoreCase = true)) {
                        result["bloodType"] = valueStr
                    } else if (keyStr.contains("محل ولادة الام", ignoreCase = true)) {
                        result["motherPlaceOfBirth"] = valueStr
                    } else if (keyStr.contains("محل ولادة الاب", ignoreCase = true)) {
                        result["fatherPlaceOfBirth"] = valueStr
                    } else if (keyStr.contains("محل الولادة", ignoreCase = true) || (keyStr.contains("محل ولادة") && !keyStr.contains("الام") && !keyStr.contains("الاب"))) {
                        result["placeOfBirth"] = valueStr
                    } else if (keyStr.contains("الرقم العائلي الحالي", ignoreCase = true)) {
                        result["familyNumber"] = valueStr
                    }
                }
            }
        } catch (e: Exception) {
            System.err.println("DG13 not found or parsing failed: ${e.message}")
        }

        // Read DG2
        try {
            val dg2In = service.getInputStream(PassportService.EF_DG2)
            val dg2File = DG2File(dg2In)
            val faceInfos = dg2File.faceInfos
            val allFaceImageInfos = mutableListOf<FaceImageInfo>()
            for (faceInfo in faceInfos) {
                allFaceImageInfos.addAll(faceInfo.faceImageInfos)
            }
            if (allFaceImageInfos.isNotEmpty()) {
                val faceImageInfo = allFaceImageInfos[0]
                val imageIn = faceImageInfo.imageInputStream
                val imageBytes = imageIn.readBytes()
                result["faceImage"] = imageBytes
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return result
    }
}
