import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/student_mark.dart';

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<List<StudentMark>> extractMarksFromImage(File imageFile, {String subject = 'General'}) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognisedText = await _textRecognizer.processImage(inputImage);
      
      List<StudentMark> studentMarks = [];
      String text = recognisedText.text;
      
      List<String> lines = text.split('\n');
      
      for (String line in lines) {
        StudentMark? mark = _parseLine(line, subject: subject);
        if (mark != null) {
          studentMarks.add(mark);
        }
      }
      
      return studentMarks;
    } catch (e) {
      if (kDebugMode) debugPrint('Error processing image: $e');
      return [];
    }
  }

  StudentMark? _parseLine(String line, {String subject = 'General'}) {
    RegExp regNumPattern = RegExp(r'[A-Z]{0,3}\d{4,10}');
    RegExp markPattern = RegExp(r'\b\d{1,3}\b');
    
    RegExpMatch? regMatch = regNumPattern.firstMatch(line);
    RegExpMatch? markMatch = markPattern.firstMatch(line);
    
    if (regMatch != null && markMatch != null) {
      String regNumber = regMatch.group(0)!;
      String mark = markMatch.group(0)!;
      
      int markValue = int.tryParse(mark) ?? -1;
      if (markValue >= 0 && markValue <= 100) {
        return StudentMark(
          registrationNumber: regNumber,
          mark: mark,
          subject: subject,
          extractedAt: DateTime.now(),
          extractionType: 'Exam',
          maxMark: 100,
        );
      }
    }
    
    return null;
  }

  Future<List<StudentMark>> extractMarksFromImages(List<File> imageFiles, {String subject = 'General'}) async {
    List<StudentMark> allMarks = [];
    
    for (File imageFile in imageFiles) {
      List<StudentMark> marks = await extractMarksFromImage(imageFile, subject: subject);
      allMarks.addAll(marks);
    }
    
    return allMarks;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
