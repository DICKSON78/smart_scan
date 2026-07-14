import 'dart:io';
import '../models/student_mark.dart';
import 'gemini_service.dart';
import 'mlkit_service.dart';

class HybridOcrService {
  final GeminiService _gemini;
  final int _minMlKitResults;

  HybridOcrService({
    int maxMark = 100,
    int minMlKitResults = 3,
  })  : _gemini = GeminiService(maxMark: maxMark),
        _minMlKitResults = minMlKitResults;

  Future<List<StudentMark>> extractMarksFromImage(
    File imageFile, {
    String subject = 'General',
    int maxMark = 100,
    String extractionType = 'Exam',
  }) async {
    // Try ML Kit first (fast, offline)
    List<StudentMark> mlKitResults = [];
    try {
      mlKitResults = await MlKitService.extractMarksFromImage(
        imageFile,
        subject: subject,
        maxMark: maxMark,
        extractionType: extractionType,
      );
    } catch (e) {
      // ML Kit failed, will try Gemini
    }

    // If ML Kit got enough results, use them
    if (mlKitResults.length >= _minMlKitResults) {
      return mlKitResults;
    }

    // Otherwise, try Gemini API for better accuracy
    try {
      final geminiResults = await _gemini.extractMarks([imageFile], maxMark: maxMark);
      if (geminiResults.isNotEmpty) {
        return geminiResults.map((g) => StudentMark(
          registrationNumber: g.regNumber,
          studentName: g.studentName,
          mark: g.mark?.toStringAsFixed(g.mark == g.mark?.roundToDouble() ? 0 : 1) ?? 'N/A',
          subject: subject,
          extractedAt: DateTime.now(),
          extractionType: extractionType,
          maxMark: maxMark,
        )).toList();
      }
    } catch (e) {
      // Gemini failed, return ML Kit results anyway
    }

    return mlKitResults;
  }

  Future<List<StudentMark>> extractMarksFromImages(
    List<File> imageFiles, {
    String subject = 'General',
    int maxMark = 100,
    String extractionType = 'Exam',
  }) async {
    final allResults = <StudentMark>[];

    for (final imageFile in imageFiles) {
      final results = await extractMarksFromImage(
        imageFile,
        subject: subject,
        maxMark: maxMark,
        extractionType: extractionType,
      );
      allResults.addAll(results);
    }

    return allResults;
  }

  void dispose() {
    MlKitService.dispose();
  }
}