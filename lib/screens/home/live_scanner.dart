import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import '../../utils/theme.dart';

class LiveScanner extends StatefulWidget {
  final bool isProcessing;
  final ValueChanged<List<File>> onProcess;
  final int maxMark;

  const LiveScanner({
    super.key,
    required this.isProcessing,
    required this.onProcess,
    required this.maxMark,
  });

  @override
  State<LiveScanner> createState() => _LiveScannerState();
}

class _LiveScannerState extends State<LiveScanner> {
  CameraController? _controller;
  bool _isCameraReady = false;
  final List<File> _capturedImages = [];
  Size _previewSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _isCameraReady = false);
        return;
      }
      _controller = CameraController(cameras.first, ResolutionPreset.medium);
      await _controller!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  Rect _scanRegion(Size previewSize) {
    final w = previewSize.width * 0.9;
    final h = previewSize.height * 0.55;
    return Rect.fromLTWH(
      (previewSize.width - w) / 2,
      (previewSize.height - h) / 2,
      w,
      h,
    );
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_isCameraReady) return;
    try {
      final xFile = await _controller!.takePicture();
      final file = File(xFile.path);
      final cropped = await _cropToScanRegion(file);
      if (mounted) setState(() => _capturedImages.add(cropped));
      unawaited(file.delete());
    } catch (e) {
      debugPrint('Capture error: $e');
    }
  }

  Future<File> _cropToScanRegion(File file) async {
    final bytes = await file.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) return file;

    final region = _scanRegion(_previewSize);
    if (region.width <= 0 || region.height <= 0) return file;

    final scaleX = original.width / _previewSize.width;
    final scaleY = original.height / _previewSize.height;
    final cropX = (region.left * scaleX).round().clamp(0, original.width);
    final cropY = (region.top * scaleY).round().clamp(0, original.height);
    final cropW = (region.width * scaleX).round().clamp(1, original.width - cropX);
    final cropH = (region.height * scaleY).round().clamp(1, original.height - cropY);

    final cropped = img.copyCrop(original, x: cropX, y: cropY, width: cropW, height: cropH);
    final jpeg = img.encodeJpg(cropped, quality: 85);
    await file.writeAsBytes(jpeg);
    return file;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width - 32;
    final previewSize = Size(screenWidth, screenWidth);

    return Column(
      children: [
        if (_isCameraReady && _controller != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.fromSize(
              size: previewSize,
              child: Stack(
                children: [
                  CameraPreview(_controller!),
                  LayoutBuilder(
                    builder: (_, constraints) {
                      _previewSize = constraints.biggest;
                      return CustomPaint(
                        size: _previewSize,
                        painter: _ScanOverlayPainter(
                          scanRegion: _scanRegion(_previewSize),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          )
        else
          _buildCameraPlaceholder(screenWidth),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isCameraReady ? _captureImage : null,
            icon: const Icon(Icons.camera_alt, size: 18),
            label: Text(
              'Capture',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: EduColors.royalBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_capturedImages.isNotEmpty) ...[
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _capturedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _capturedImages[index],
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _capturedImages.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 10, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _capturedImages.isNotEmpty
                  ? () => widget.onProcess(List.from(_capturedImages))
                  : null,
              icon: widget.isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_fix_high, size: 18),
              label: Text(
                widget.isProcessing ? 'Processing...' : 'Process (${_capturedImages.length})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: EduColors.royalBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor: EduColors.royalBlue.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCameraPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: EduColors.royalBlueLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EduColors.cardBorder, width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 40, color: EduColors.royalBlue),
            const SizedBox(height: 8),
            Text(
              'Camera unavailable',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: EduColors.textMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  final Rect scanRegion;

  _ScanOverlayPainter({required this.scanRegion});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(scanRegion, const Radius.circular(8))),
      ),
      overlayPaint,
    );

    final borderPaint = Paint()
      ..color = EduColors.royalBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(RRect.fromRectAndRadius(scanRegion, const Radius.circular(8)), borderPaint);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) => scanRegion != old.scanRegion;
}
