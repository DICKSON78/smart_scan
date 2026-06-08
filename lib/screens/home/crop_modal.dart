import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/theme.dart';
import '../../widgets/dialog_header.dart';

class CropModal extends StatefulWidget {
  final File imageFile;
  final void Function(File croppedImage) onCropped;

  const CropModal({
    super.key,
    required this.imageFile,
    required this.onCropped,
  });

  @override
  State<CropModal> createState() => _CropModalState();
}

class _CropModalState extends State<CropModal> {
  final TransformationController _transformController = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  double _zoom = 1.0;
  ui.Image? _loadedImage;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _loadedImage = frame.image;
      _imageSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _crop() async {
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      widget.onCropped(tempFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Crop failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DialogHeader(
            icon: Icons.crop,
            title: 'Crop Image',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text('${(_zoom * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ),
          if (_loadedImage == null)
            const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 400,
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: _repaintKey,
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 1.0,
                        maxScale: 4.0,
                        onInteractionEnd: (_) {
                          final matrix = _transformController.value;
                          setState(() => _zoom = matrix.getMaxScaleOnAxis());
                        },
                        child: Center(
                          child: RawImage(
                            image: _loadedImage,
                            width: _imageSize!.width.clamp(0, 300),
                            height: _imageSize!.height.clamp(0, 400),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    // Crosshair overlay
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 250,
                          height: 350,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    // Zoom controls
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _zoomButton(Icons.add, () {
                            final current = _transformController.value;
                            current.setEntry(0, 0, current.entry(0, 0) * 1.2);
                            current.setEntry(1, 1, current.entry(1, 1) * 1.2);
                            _transformController.value = current;
                            setState(() => _zoom = current.getMaxScaleOnAxis());
                          }),
                          const SizedBox(height: 4),
                          _zoomButton(Icons.remove, () {
                            final current = _transformController.value;
                            current.setEntry(0, 0, current.entry(0, 0) * 0.8);
                            current.setEntry(1, 1, current.entry(1, 1) * 0.8);
                            _transformController.value = current;
                            setState(() => _zoom = current.getMaxScaleOnAxis());
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.zoom_out, size: 16, color: EduColors.textLight),
                Expanded(
                  child: Slider(
                    value: _zoom,
                    min: 1.0,
                    max: 4.0,
                    activeColor: EduColors.royalBlue,
                    onChanged: (v) {
                      final current = _transformController.value;
                      final s = v / _zoom;
                      current.setEntry(0, 0, current.entry(0, 0) * s);
                      current.setEntry(1, 1, current.entry(1, 1) * s);
                      _transformController.value = current;
                      setState(() => _zoom = v);
                    },
                  ),
                ),
                const Icon(Icons.zoom_in, size: 16, color: EduColors.textLight),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: EduColors.cardBorder))),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text('Cancel', style: GoogleFonts.poppins()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      _crop();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EduColors.royalBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Crop', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}
