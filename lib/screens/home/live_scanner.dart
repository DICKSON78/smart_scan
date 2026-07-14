import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
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

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (kDebugMode) debugPrint('Camera permission denied');
        if (mounted) setState(() => _isCameraReady = false);
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _isCameraReady = false);
        return;
      }
      _controller = CameraController(cameras.first, ResolutionPreset.medium);
      await _controller!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      if (kDebugMode) debugPrint('Camera init error: $e');
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_isCameraReady) return;
    try {
      final xFile = await _controller!.takePicture();
      final file = File(xFile.path);
      if (mounted) setState(() => _capturedImages.add(file));
    } catch (e) {
      if (kDebugMode) debugPrint('Capture error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width - 32;
    final previewSize = Size(screenWidth, screenWidth * 4 / 3);

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
                ],
              ),
            ),
          )
        else
          _buildCameraPlaceholder(previewSize),
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

  Widget _buildCameraPlaceholder(Size size) {
    return Container(
      width: size.width,
      height: size.height,
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


