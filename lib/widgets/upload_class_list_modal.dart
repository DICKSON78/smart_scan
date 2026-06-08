import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
import '../models/student_mark.dart';
import '../utils/theme.dart';
import 'dialog_header.dart';

class _ClassEntry {
  final String regNumber;
  final String name;
  const _ClassEntry({required this.regNumber, required this.name});
}

class UploadClassListModal extends StatefulWidget {
  final List<StudentMark> existingClassList;
  final ValueChanged<List<StudentMark>> onConfirm;
  final VoidCallback onClose;

  const UploadClassListModal({
    super.key,
    required this.existingClassList,
    required this.onConfirm,
    required this.onClose,
  });

  @override
  State<UploadClassListModal> createState() => _UploadClassListModalState();
}

class _UploadClassListModalState extends State<UploadClassListModal> {
  List<StudentMark> _parsedStudents = [];
  String? _error;
  bool _isParsing = false;

  @override
  void initState() {
    super.initState();
    _parsedStudents = List.from(widget.existingClassList);
  }

  List<StudentMark> _entriesToMarks(List<_ClassEntry> entries) {
    return entries.map((e) => StudentMark(
      registrationNumber: e.regNumber,
      studentName: e.name,
      mark: 'N/A',
      subject: '',
      extractedAt: DateTime.now(),
      maxMark: 100,
    )).toList();
  }

  void _handleFilePick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.first.path!);
    await _parseFile(file);
  }

  Future<void> _parseFile(File file) async {
    setState(() {
      _isParsing = true;
      _error = null;
    });
    try {
      final ext = file.path.split('.').last.toLowerCase();
      List<StudentMark> parsed;
      if (ext == 'csv') {
        parsed = await _parseCsv(file);
      } else {
        parsed = await _parseExcel(file);
      }
      if (parsed.isEmpty) {
        setState(() => _error = 'No student records found in file');
      } else {
        setState(() => _parsedStudents = parsed);
      }
    } catch (e) {
      setState(() => _error = 'Failed to parse file: $e');
    } finally {
      setState(() => _isParsing = false);
    }
  }

  Future<List<StudentMark>> _parseCsv(File file) async {
    final content = await file.readAsString();
    final lines = content.split('\n');
    final entries = <_ClassEntry>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = _splitCsvLine(trimmed);
      if (parts.isEmpty) continue;
      final col0 = parts[0].trim();
      if (col0.isEmpty || _isHeader(col0)) continue;
      if (parts.length >= 2) {
        final name = parts[1].trim();
        if (name.isNotEmpty && !_isHeader(name)) {
          entries.add(_ClassEntry(regNumber: col0, name: name));
        }
      } else if (!_isNumber(col0)) {
        final pos = entries.length + 1;
        entries.add(_ClassEntry(regNumber: 'S/${pos.toString().padLeft(3, '0')}', name: col0));
      }
    }
    return _entriesToMarks(entries);
  }

  Future<List<StudentMark>> _parseExcel(File file) async {
    final bytes = await file.readAsBytes();
    final excel = excel_pkg.Excel.decodeBytes(bytes);
    final entries = <_ClassEntry>[];
    for (final table in excel.sheets.values) {
      for (final row in table.rows) {
        if (row.isEmpty) continue;
        final cell0 = row[0];
        if (cell0 == null || cell0.value == null) continue;
        final col0 = cell0.value.toString().trim();
        if (col0.isEmpty || _isHeader(col0)) continue;
        if (row.length >= 2) {
          final cell1 = row[1];
          final name = cell1?.value?.toString().trim() ?? '';
          if (name.isNotEmpty && !_isHeader(name)) {
            entries.add(_ClassEntry(regNumber: col0, name: name));
          }
        } else if (!_isNumber(col0)) {
          final pos = entries.length + 1;
          entries.add(_ClassEntry(regNumber: 'S/${pos.toString().padLeft(3, '0')}', name: col0));
        }
      }
      if (entries.isNotEmpty) break;
    }
    return _entriesToMarks(entries);
  }

  bool _isHeader(String s) {
    final lower = s.toLowerCase().trim();
    return [
      'name', 'student name', 'student', 'names', 'full name',
      'registration number', 'reg no', 'reg. no', 'reg_no',
      'registration', 's/n', 'sn', 'no', 'number', 'namba',
      'jina', 'majina', 'mwanafunzi', 'class list',
      'admission', 'admission no', 'admission number', 'index',
      'index number', 'serial', 'serial number', '#',
    ].contains(lower);
  }

  bool _isNumber(String s) => double.tryParse(s) != null;

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    final current = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(c);
      }
    }
    result.add(current.toString());
    return result;
  }

  void _confirm() {
    if (_parsedStudents.isEmpty) return;
    widget.onConfirm(_parsedStudents);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DialogHeader(
            icon: Icons.people_outline,
            title: 'Upload Class List',
            subtitle: 'Add student names to map voice entries',
            count: _parsedStudents.length,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildUploadTab(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: EduColors.cardBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onClose,
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _parsedStudents.isNotEmpty ? _confirm : null,
                  child: Text(
                    'Add ${_parsedStudents.length} ${_parsedStudents.length == 1 ? 'Student' : 'Students'}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTab() {
    return Column(
      children: [
        GestureDetector(
          onTap: _isParsing ? null : _handleFilePick,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: EduColors.royalBlue.withValues(alpha: 0.3), width: 2),
              borderRadius: BorderRadius.circular(12),
              color: EduColors.royalBlueLight.withValues(alpha: 0.3),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined, size: 40, color: EduColors.royalBlue.withValues(alpha: 0.6)),
                const SizedBox(height: 8),
                Text(
                  _isParsing ? 'Parsing...' : 'Tap to select Excel or CSV',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: EduColors.textMedium),
                ),
                const SizedBox(height: 4),
                Text(
                  'Expected: Reg No column + Name column',
                  style: GoogleFonts.poppins(fontSize: 10, color: EduColors.textLight),
                ),
              ],
            ),
          ),
        ),
        if (_isParsing) ...[
          const SizedBox(height: 12),
          const CircularProgressIndicator(strokeWidth: 2),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: EduColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!, style: GoogleFonts.poppins(fontSize: 12, color: EduColors.error)),
          ),
        ],
        if (_parsedStudents.isNotEmpty && !_isParsing) ...[
          const SizedBox(height: 12),
          _buildStudentListPreview(),
        ],
      ],
    );
  }

  Widget _buildStudentListPreview() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: EduColors.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: EduColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Text(
              '${_parsedStudents.length} Students Loaded',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: EduColors.textLight),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(6),
              itemCount: _parsedStudents.length,
              itemBuilder: (_, i) {
                final s = _parsedStudents[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: EduColors.royalBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          s.registrationNumber,
                          style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: EduColors.royalBlue),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.studentName ?? s.registrationNumber,
                          style: GoogleFonts.poppins(fontSize: 11, color: EduColors.textDark),
                          overflow: TextOverflow.ellipsis,
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
}
