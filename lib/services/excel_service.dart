import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../models/student_mark.dart';

class ExcelService {
  static const _primary = '1A56DB';
  static const _primaryLight = 'E8EEFB';
  static const _white = 'FFFFFF';
  static const _darkText = '2D3436';
  static const _borderColor = 'DFE6E9';
  static const _headerBg = '1A56DB';
  static const _headerText = 'FFFFFF';
  static const _altRowBg = 'F8F9FC';

  Future<File> _generateSingleSheet(List<StudentMark> marks, String subject) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final safeName = subject.replaceAll(RegExp(r'[\/\\\?\*\[\]]'), '_');
    final sheet = excel[safeName];

    final maxMark = marks.first.maxMark;

    sheet.setColumnWidth(0, 8);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 22);
    sheet.setColumnWidth(3, 14);

    final colCount = 4;
    final extractionType = marks.first.extractionType;

    // ── Subject + type title row ──
    sheet.appendRow([TextCellValue('$subject - $extractionType')]);
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: colCount - 1, rowIndex: 0),
    );
    _styleCell(sheet, 0, 0, bold: true, size: 13, color: _darkText, bg: _primaryLight);

    // ── Column headers ──
    final headers = ['S/No', 'Name', 'Registration No', 'Marks ($maxMark)'];
    final headerRowIdx = 1;
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (int c = 0; c < colCount; c++) {
      _styleCell(sheet, headerRowIdx, c, bold: true, size: 11, color: _headerText, bg: _headerBg);
      _setBorder(sheet, headerRowIdx, c, headerRowIdx, c);
    }

    // ── Data rows ──
    for (int i = 0; i < marks.length; i++) {
      final m = marks[i];
      final score = double.tryParse(m.mark);
      final isValid = score != null;
      final isEven = i.isEven;
      final rowIdx = headerRowIdx + 1 + i;

      final rowData = <CellValue?>[
        IntCellValue(i + 1),
        TextCellValue(m.studentName ?? ''),
        TextCellValue(m.registrationNumber),
        isValid ? IntCellValue(score.toInt()) : TextCellValue(m.mark),
      ];
      sheet.appendRow(rowData);

      for (int c = 0; c < colCount; c++) {
        _styleCell(sheet, rowIdx, c, size: 11, color: _darkText, bg: isEven ? _white : _altRowBg);
        _setBorder(sheet, rowIdx, c, rowIdx, c);
      }
    }

    final directory = await getTemporaryDirectory();
    final sanitized = subject.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final path = '${directory.path}/$sanitized.xlsx';
    final file = File(path);
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Excel encoding returned null');
    }
    await file.writeAsBytes(bytes);
    return file;
  }

  void _styleCell(Sheet sheet, int row, int col, {
    bool bold = false,
    int size = 11,
    String color = _darkText,
    String bg = _white,
  }) {
    final idx = CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);
    sheet.cell(idx).cellStyle = CellStyle(
      bold: bold,
      fontSize: size,
      fontColorHex: ExcelColor.fromHexString(color),
      backgroundColorHex: ExcelColor.fromHexString(bg),
    );
  }

  void _setBorder(Sheet sheet, int row1, int col1, int row2, int col2) {
    final start = CellIndex.indexByColumnRow(columnIndex: col1, rowIndex: row1);
    final cell = sheet.cell(start);
    final style = cell.cellStyle ?? CellStyle();
    final border = Border(borderColorHex: ExcelColor.fromHexString(_borderColor));
    cell.cellStyle = style.copyWith(
      topBorderVal: border,
      bottomBorderVal: border,
      leftBorderVal: border,
      rightBorderVal: border,
    );
  }

  Future<String> _generateCsv(List<StudentMark> marks, String subject) async {
    final buffer = StringBuffer();
    buffer.writeln('SMARTSCAN MARKS');
    buffer.writeln('Subject,$subject');
    buffer.writeln('Total Students,${marks.length}');
    buffer.writeln('');
    buffer.writeln('S/No,Name,Registration No,Marks');
    for (int i = 0; i < marks.length; i++) {
      final m = marks[i];
      final name = (m.studentName ?? '').replaceAll(',', ' ');
      buffer.writeln('${i + 1},$name,${m.registrationNumber},${m.mark}');
    }
    final directory = await getTemporaryDirectory();
    final sanitized = subject.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final path = '${directory.path}/$sanitized.csv';
    final file = File(path);
    await file.writeAsString(buffer.toString());
    return path;
  }

  Future<String> generateExport(List<StudentMark> marks, String subject) async {
    if (marks.isEmpty) throw Exception('No marks to export');
    try {
      final file = await _generateSingleSheet(marks, subject);
      return file.path;
    } catch (_) {
      return _generateCsv(marks, subject);
    }
  }

  Future<void> shareExport(List<StudentMark> marks, String subject) async {
    try {
      final path = await generateExport(marks, subject);
      final isCsv = path.endsWith('.csv');
      await share_plus.SharePlus.instance.share(
        share_plus.ShareParams(
          files: [share_plus.XFile(path)],
          text: isCsv ? 'Exam marks exported (CSV)' : 'Exam marks exported',
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, File>> generateExcelFilesPerSubject(
    Map<String, List<StudentMark>> groupedMarks,
  ) async {
    final files = <String, File>{};
    for (final entry in groupedMarks.entries) {
      if (entry.value.isNotEmpty) {
        final path = await generateExport(entry.value, entry.key);
        files[entry.key] = File(path);
      }
    }
    return files;
  }

  Future<File> generateExcelFile(List<StudentMark> studentMarks, String examName) async {
    if (studentMarks.isEmpty) throw Exception('No marks to export');
    final subject = studentMarks.first.subject;
    final path = await generateExport(studentMarks, subject);
    return File(path);
  }

  Future<void> shareExcelFiles(Map<String, File> files) async {
    final xFiles = files.values.map((f) => share_plus.XFile(f.path)).toList();
    await share_plus.SharePlus.instance.share(
      share_plus.ShareParams(files: xFiles, text: 'Exam marks exported by subject'),
    );
  }

  Future<void> shareExcelFile(File file) async {
    await share_plus.SharePlus.instance.share(
      share_plus.ShareParams(
        files: [share_plus.XFile(file.path)],
        text: 'Exam marks extracted',
      ),
    );
  }

  Future<void> shareAsCsv(Map<String, List<StudentMark>> groupedMarks) async {
    for (final entry in groupedMarks.entries) {
      if (entry.value.isNotEmpty) {
        await shareExport(entry.value, entry.key);
      }
    }
  }
}
