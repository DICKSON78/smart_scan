import 'dart:io';
import '../models/student_mark.dart';
import 'gemini_service.dart';

class HybridOcrService {
  final GeminiService _gemini;

  HybridOcrService({
    int maxMark = 100,
  }) : _gemini = GeminiService(maxMark: maxMark);

  Future<List<StudentMark>> extractMarksFromImage(
    File imageFile, {
    String subject = 'General',
    int maxMark = 100,
    String extractionType = 'Exam',
  }) async {
    final geminiResults = await _gemini.extractMarks([imageFile], maxMark: maxMark);
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

  void dispose() {}
}
