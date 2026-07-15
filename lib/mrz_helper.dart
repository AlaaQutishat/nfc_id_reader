import 'package:flutter/widgets.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MrzHelper {
  /// Extracts MRZ fields from OCR text.
  ///
  /// Works on both Android and iOS by iterating `blocks` → `lines` directly
  /// rather than splitting the combined `.text` string, and by aggressively
  /// normalising each line before parsing.
  static Map<String, String>? extractMRZ(RecognizedText recognizedText) {
    // ─── 1. Collect all candidate lines from blocks ──────────────────────────
    final List<String> rawLines = [];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        rawLines.add(line.text);
      }
    }

    // Also fall back to splitting the combined text in case blocks are empty.
    if (rawLines.isEmpty) {
      rawLines.addAll(recognizedText.text.split('\n'));
    }

    // ─── 2. Normalise each line ───────────────────────────────────────────────
    final List<String> lines = rawLines
        .map(_normaliseLine)
        .where((l) => l.length > 10)
        .toList();

    debugPrint('[MRZ-DEBUG] Normalised lines (${lines.length}):');
    for (final l in lines) {
      debugPrint('[MRZ-DEBUG]  "$l"');
    }

    // ─── 3. Find the line that contains DOB + sex + expiry ───────────────────
    // TD1 line 2 pattern: 6 digits + check + M/F/< + 6 digits + check + ...
    // TD3 line 2 pattern: same structure
    final dateLineRegex = RegExp(r'([0-9]{6})[0-9][MF<]([0-9]{6})');

    String? dob;
    String? expiry;
    String? dateLine; // keep reference so we can skip it later

    for (final line in lines) {
      final match = dateLineRegex.firstMatch(line);
      if (match != null) {
        dob = match.group(1);
        expiry = match.group(2);
        dateLine = line;
        debugPrint(
          '[MRZ-DEBUG] Date line matched: "$line"  dob=$dob expiry=$expiry',
        );
        break;
      }
    }

    if (dob == null || expiry == null) {
      debugPrint('[MRZ-DEBUG] Could not find date line — extraction failed.');
      return null;
    }

    // ─── 4. Find the document number ─────────────────────────────────────────
    String? docNum;

    for (final line in lines) {
      if (line == dateLine) continue; // skip the date line
      if (line.contains(dob)) continue; // skip if it accidentally has the DOB

      // Strategy A: look for "IRQ" and take what follows
      if (line.contains('IRQ')) {
        final idx = line.indexOf('IRQ');
        if (idx != -1 && line.length > idx + 3) {
          final after = line.substring(idx + 3).replaceAll('<', '');
          if (after.length >= 6) {
            // Take up to 9 alphanumeric characters
            final match = RegExp(r'[A-Z0-9]{6,9}').firstMatch(after);
            if (match != null) {
              docNum = match.group(0);
              debugPrint('[MRZ-DEBUG] Doc number via IRQ strategy: $docNum');
              break;
            }
          }
        }
      }
    }

    // Strategy B: common MRZ prefixes — look for I< or P< then country code
    if (docNum == null) {
      final prefixRegex = RegExp(r'^[IAP][A-Z<][A-Z]{3}([A-Z0-9<]{9})');
      for (final line in lines) {
        if (line == dateLine) continue;
        if (line.contains(dob)) continue;

        final match = prefixRegex.firstMatch(line);
        if (match != null) {
          final candidate = match.group(1)!.replaceAll('<', '');
          if (candidate.length >= 6) {
            docNum = candidate;
            debugPrint('[MRZ-DEBUG] Doc number via prefix strategy: $docNum');
            break;
          }
          docNum = null;
        }
      }
    }

    // Strategy C: any line with << that has a long alphanumeric block
    if (docNum == null) {
      for (final line in lines) {
        if (line == dateLine) continue;
        if (line.contains(dob)) continue;
        if (!line.contains('<<')) continue;

        final cleaned = line.replaceAll('<', '');
        final match = RegExp(r'[A-Z0-9]{6,9}').firstMatch(cleaned);
        if (match != null) {
          docNum = match.group(0)!;
          debugPrint('[MRZ-DEBUG] Doc number via << strategy: $docNum');
          break;
        }
      }
    }

    // Strategy D: last resort — any line that looks alphanumeric-heavy and long
    if (docNum == null) {
      for (final line in lines) {
        if (line == dateLine) continue;
        if (line.contains(dob)) continue;
        if (line.length < 15) continue;

        final cleaned = line.replaceAll('<', '');
        // At least 60 % of characters should be alphanumeric → looks like MRZ
        final alphaCount = cleaned.replaceAll(RegExp(r'[^A-Z0-9]'), '').length;
        if (cleaned.isNotEmpty && (alphaCount / cleaned.length) > 0.6) {
          final match = RegExp(r'[A-Z0-9]{6,9}').firstMatch(cleaned);
          if (match != null) {
            docNum = match.group(0)!;
            debugPrint(
              '[MRZ-DEBUG] Doc number via last-resort strategy: $docNum',
            );
            break;
          }
        }
      }
    }

    if (docNum == null) {
      debugPrint(
        '[MRZ-DEBUG] Could not find document number — extraction failed.',
      );
      return null;
    }

    debugPrint(
      '[MRZ-DEBUG] Final result: docNum=$docNum dob=$dob expiry=$expiry',
    );
    return {'docNumber': docNum, 'dob': dob, 'expiry': expiry};
  }

  /// Normalises a single OCR line for MRZ parsing:
  /// - strips spaces (iOS ML Kit often inserts spaces between chars)
  /// - replaces common OCR misreads of the `<` fill character
  /// - uppercases everything
  static String _normaliseLine(String raw) {
    // Remove all whitespace (spaces, tabs)
    String s = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();

    // Replace common OCR misreadings of '<'
    // Only replace when the character is surrounded by plausible MRZ context
    // (i.e., when the string is mostly alphanumeric + '<' already)
    s = s
        .replaceAll('«', '<<')
        .replaceAll('»', '>>')
        // Single-char substitutes for '<' that ML Kit commonly returns on iOS
        .replaceAll('—', '<')
        .replaceAll('–', '<')
        .replaceAll('‐', '<')
    // Period or dash at position boundary sometimes replaces '<'
    // Only do this if the line looks like an MRZ line (long enough)
    ;

    if (s.length > 20) {
      // In a long line, isolated dots and commas between alnum chars → '<'
      s = s.replaceAllMapped(
        RegExp(r'(?<=[A-Z0-9])[.,_-](?=[A-Z0-9])'),
        (_) => '<',
      );
    }

    return s;
  }

  static bool validateMRZ(Map<String, String> data) {
    if (!_isValidDate(data['dob']) || !_isValidDate(data['expiry'])) {
      return false;
    }

    if ((data['docNumber']?.length ?? 0) < 6) return false;

    return true;
  }

  static bool _isValidDate(String? date) {
    if (date == null || date.length != 6) return false;
    // YYMMDD
    final year = int.tryParse(date.substring(0, 2));
    final month = int.tryParse(date.substring(2, 4));
    final day = int.tryParse(date.substring(4, 6));

    if (year == null || month == null || day == null) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;
    return true;
  }
}
