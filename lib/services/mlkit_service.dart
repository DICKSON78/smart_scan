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
    final parts = line.split(RegExp(r'\s{2,}|\t'));
    if (parts.length < 2) return null;

    parts.removeWhere((p) => p.isEmpty);

    final last = parts.last.trim();
    final markVal = num.tryParse(last);

    if (markVal == null || markVal < 0 || markVal > maxMark) return null;

    if (parts.length == 2) {
      return (parts[0].trim(), null, markVal);
    }

    final regNum = parts[0].trim();
    final name = parts.sublist(1, parts.length - 1).join(' ').trim();
    return (regNum, name.isNotEmpty ? name : null, markVal);
  }
}