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
          model: 'gemini-2.5-pro',
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
                    description: 'The exact numeric score. Must be 0 or higher.'),
              },
              requiredProperties: ['studentId', 'studentName', 'mark'],
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
        'You are an OCR assistant for Tanzanian university exam mark sheets.\n\n'
        'Extract EVERY student record visible in the image(s) as a JSON array.\n\n'
        'Rules:\n'
        '1. studentId: Copy the registration/admission number EXACTLY as written (e.g., "S.1/001", "2023/CS/001", "T/1234"). Do NOT modify, increment, or fabricate it.\n'
        '2. studentName: Copy the student\'s full name exactly as written. Use empty string if no name column exists.\n'
        '3. mark: The numeric score EXACTLY as written (e.g., 68, 45.5, 72). Must be a number. Do NOT guess, estimate, or make up marks.\n'
        '4. If a student has no score written, set mark to null (but still include them).\n'
        '5. Maximum possible mark is $maxMark.\n'
        '6. Include ALL students in the order they appear on the sheet.\n'
        '7. Output ONLY a valid JSON array — no preamble, no explanation.\n'
        '8. The OCR must be precise: every digit and character matters.\n'
        '9. Ignore header rows (e.g., "Reg No", "Name", "Score", "Marks") — do not include them as data.',
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
