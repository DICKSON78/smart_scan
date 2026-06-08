import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/theme.dart';

class ImageUploader extends StatelessWidget {
  final List<File> files;
  final ValueChanged<List<File>> onFilesAdded;
  final ValueChanged<int> onFileRemoved;
  final VoidCallback onClearAll;

  const ImageUploader({
    super.key,
    required this.files,
    required this.onFilesAdded,
    required this.onFileRemoved,
    required this.onClearAll,
  });

  static const _allowedExtensions = [
    'png', 'jpg', 'jpeg',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDropZone(),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildFileList(),
        ],
      ],
    );
  }

  Widget _buildDropZone() {
    final hasImages = files.any((f) => ['png', 'jpg', 'jpeg'].contains(f.path.split('.').last.toLowerCase()));
    final imageCount = files.where((f) => ['png', 'jpg', 'jpeg'].contains(f.path.split('.').last.toLowerCase())).length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _pickFiles,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: EduColors.royalBlue.withValues(alpha: 0.3),
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
            borderRadius: BorderRadius.circular(12),
            color: EduColors.royalBlueLight.withValues(alpha: 0.3),
          ),
          child: Column(
            children: [
              Icon(
                hasImages ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
                size: 40,
                color: hasImages ? Colors.green : EduColors.royalBlue.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 8),
              Text(
                hasImages ? '$imageCount image${imageCount > 1 ? 's' : ''} selected' : 'Tap to select images',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasImages ? Colors.green : EduColors.textMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasImages ? 'Tap to add more' : 'PNG, JPG, JPEG — select multiple at once',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: EduColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileList() {
    return Container(
      decoration: BoxDecoration(
        color: EduColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EduColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: EduColors.cardBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected (${files.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: EduColors.textLight,
                  ),
                ),
                GestureDetector(
                  onTap: onClearAll,
                  child: Text(
                    'Clear All',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: EduColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final name = file.path.split('/').last;
                final ext = name.split('.').last.toUpperCase();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: index < files.length - 1
                        ? Border(bottom: BorderSide(color: EduColors.cardBorder.withValues(alpha: 0.5)))
                        : null,
                  ),
                  child: Row(
                    children: [
                      _fileIcon(ext),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: EduColors.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => onFileRemoved(index),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: EduColors.textLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileIcon(String ext) {
    IconData icon;
    Color color;
    switch (ext) {
      case 'XLSX':
      case 'XLS':
        icon = Icons.table_chart;
        color = Colors.green;
        break;
      case 'CSV':
        icon = Icons.description;
        color = Colors.orange;
        break;
      case 'PDF':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'DOCX':
        icon = Icons.article;
        color = Colors.blue;
        break;
      default:
        icon = Icons.image;
        color = EduColors.royalBlue;
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: color),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      onFilesAdded(result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList());
    }
  }
}
