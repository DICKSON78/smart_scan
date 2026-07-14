import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;

class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);
  @override
  String toString() => message;
}

class GeminiExtractionResult {
  final String regNumber;
  final String? studentName;
  final double? mark;

  GeminiExtractionResult({required this.regNumber, this.studentName, this.mark});
}

Uint8List _resizeImageBytesSync(Map<String, dynamic> params) {
  final bytes = params['bytes'] as Uint8List;
  final maxDim = params['maxDim'] as int;
  final quality = params['quality'] as int;
  final original = img.decodeImage(bytes);
  if (original == null) return bytes;

  int w = original.width;
  int h = original.height;

  if (w > maxDim || h > maxDim) {
    if (w > h) {
      h = (h * maxDim / w).round();
      w = maxDim;
    } else {
      w = (w * maxDim / h).round();
      h = maxDim;
    }
  }

  if (w == original.width && h == original.height) {
    return bytes;
  }

  final resized = img.copyResize(original, width: w, height: h);
  return img.encodeJpg(resized, quality: quality);
}

class GeminiService {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  final GenerativeModel _model;
  final int _maxRetries = 3;

  GeminiService({int maxMark = 100})
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: _apiKey,
          generationConfig: GenerationConfig(
            temperature: 0,
            responseMimeType: 'application/json',
            responseSchema: Schema(SchemaType.array, items: Schema(
              SchemaType.object,
              properties: {
                'studentId': Schema(SchemaType.string,
                    description: 'Student registration or admission number exactly as written'),
                'studentName': Schema(SchemaType.string,
                    description: 'Student full name if visible, otherwise empty string'),
                'mark': Schema(SchemaType.number,
                    description: 'The numeric score exactly as written'),
              },
              requiredProperties: ['studentId', 'mark'],
            )),
          ),
        );

  Future<List<GeminiExtractionResult>> extractMarks(
    List<File> images, {
    int maxMark = 100,
  }) async {
    return _extractWithRetry(images, maxMark, 0);
  }

  Future<List<GeminiExtractionResult>> _extractWithRetry(
    List<File> images,
    int maxMark,
    int attempt,
  ) async {
    try {
      final imageParts = await Future.wait(images.map(_resizeImage));

      final prompt = TextPart(
        'OCR Task: Extract student records from this mark sheet or assignment image.\n\n'
        'For EACH student row, extract:\n'
        '1. studentId: The Registration Number or Student ID exactly as written\n'
        '2. studentName: The Student Name exactly as written\n'
        '3. mark: The numeric score exactly as written\n\n'
        'Rules:\n'
        '- Extract ALL student records visible in the image\n'
        '- Copy every character exactly — do not modify, guess, or fabricate\n'
        '- Max mark is $maxMark. If mark exceeds $maxMark, set to null\n'
        '- If a field is not visible, use empty string\n'
        '- Ignore headers, column titles, page numbers, totals, averages\n'
        '- Return ONLY a valid JSON array. No other text.',
      );

      final response = await _model.generateContent([
        Content.multi([prompt, ...imageParts]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        throw const GeminiException('Empty response from Gemini');
      }

      final List<dynamic> data = json.decode(text);
      return data.map((e) {
        final id = e['studentId']?.toString().trim() ?? '';
        final name = e['studentName']?.toString().trim() ?? '';
        final markVal = e['mark'];
        double? mark;
        if (markVal is num && markVal >= 0 && markVal <= maxMark) {
          mark = markVal.toDouble();
        }
        return GeminiExtractionResult(
          regNumber: id,
          studentName: name.isNotEmpty ? name : null,
          mark: mark,
        );
      }).where((r) => r.regNumber.isNotEmpty).toList();
    } on GeminiException catch (_) {
      rethrow;
    } catch (e) {
      final msg = e.toString();
      if (_isRetryable(msg) && attempt < _maxRetries) {
        final wait = pow(2, attempt).toInt() * 1000 + Random().nextInt(1000);
        await Future.delayed(Duration(milliseconds: wait));
        return _extractWithRetry(images, maxMark, attempt + 1);
      }
      rethrow;
    }
  }

  bool _isRetryable(String msg) {
    return msg.contains('429') ||
        msg.contains('RESOURCE_EXHAUSTED') ||
        msg.contains('500') ||
        msg.contains('503');
  }

  Future<DataPart> _resizeImage(File file) async {
    final bytes = await file.readAsBytes();
    final result = await compute(_resizeImageBytesSync, {
      'bytes': bytes,
      'maxDim': 1600,
      'quality': 70,
    });
    return DataPart('image/jpeg', result);
  }
}
