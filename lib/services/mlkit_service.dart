import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/student_mark.dart';

class MlKitService {
  static final TextRecognizer _sharedRecognizer = TextRecognizer();

  static Future<List<StudentMark>> extractMarksFromImage(
    File imageFile, {
    String subject = 'General',
    int maxMark = 100,
    String extractionType = 'Exam',
  }) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _sharedRecognizer.processImage(inputImage);
    final lines = recognizedText.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final results = <StudentMark>[];
    for (final line in lines) {
      final parsed = _parseLine(line, maxMark);
      if (parsed != null) {
        results.add(StudentMark(
          registrationNumber: parsed.$1,
          studentName: parsed.$2,
          mark: parsed.$3.toString(),
          subject: subject,
          extractedAt: DateTime.now(),
          extractionType: extractionType,
          maxMark: maxMark,
        ));
      }
    }
    return results;
  }

  /// Returns the full RecognizedText for cropping analysis.
  static Future<RecognizedText> recognizeText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    return _sharedRecognizer.processImage(inputImage);
  }

  static Future<List<List<StudentMark>>> extractMarksFromImages(
    List<File> imageFiles, {
    String subject = 'General',
    int maxMark = 100,
    String extractionType = 'Exam',
  }) async {
    final allResults = <List<StudentMark>>[];
    for (final f in imageFiles) {
      try {
        final result = await extractMarksFromImage(
          f,
          subject: subject,
          maxMark: maxMark,
          extractionType: extractionType,
        );
        allResults.add(result);
      } catch (_) {
        allResults.add([]);
      }
    }
    return allResults;
  }

  static void dispose() {
    _sharedRecognizer.close();
  }

  static (String, String?, num)? _parseLine(String line, int maxMark) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    // Find the last number in the line as the mark
    final markMatch = RegExp(r'(\d+(?:\.\d+)?)\s*$').firstMatch(trimmed);
    if (markMatch == null) return null;

    final markVal = num.tryParse(markMatch.group(1)!);
    if (markVal == null || markVal < 0 || markVal > maxMark) return null;

    // Everything before the mark is reg number + name
    final beforeMark = trimmed.substring(0, markMatch.start).trim();
    if (beforeMark.isEmpty) return null;

    // Split by 2+ spaces, tabs, pipes, or commas first
    final parts = beforeMark.split(RegExp(r'\s{2,}|\t|\||,'));
    if (parts.length >= 2) {
      parts.removeWhere((p) => p.trim().isEmpty);
      final regNum = parts[0].trim();
      final name = parts.sublist(1).join(' ').trim();
      return (regNum, name.isNotEmpty ? name : null, markVal);
    }

    // Single separator — try to split reg number from name
    // Reg numbers typically contain digits and punctuation like / . -
    final text = beforeMark.trim();
    final regMatch = RegExp(r'^([\w\/\.\-]+)\s+(.+)$').firstMatch(text);
    if (regMatch != null) {
      final name = regMatch.group(2)!.trim();
      return (regMatch.group(1)!, name.isNotEmpty ? name : null, markVal);
    }

    // No clear separator — return whole text as reg number
    return (text, null, markVal);
  }
}