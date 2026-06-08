import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

Uint8List _compressBytesSync(Map<String, dynamic> params) {
  final bytes = params['bytes'] as Uint8List;
  final quality = params['quality'] as int;
  final maxDim = params['maxDim'] as int;
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
    final resized = img.copyResize(original, width: w, height: h);
    return img.encodeJpg(resized, quality: quality);
  }

  return img.encodeJpg(original, quality: quality);
}

class ImageProcessor {
  static const int maxDimension = 1024;
  static const int compressionQuality = 60;

  static Future<File> compressImage(File file, {int? quality}) async {
    final q = quality ?? compressionQuality;
    final bytes = await file.readAsBytes();
    final result = await compute(_compressBytesSync, {
      'bytes': bytes,
      'quality': q,
      'maxDim': maxDimension,
    });
    await file.writeAsBytes(result);
    return file;
  }

  static Future<List<File>> compressImages(List<File> files) async {
    return Future.wait(files.map((f) => compressImage(f)));
  }
}
