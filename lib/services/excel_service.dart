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
  static const _mediumText = '636E72';
  static const _borderColor = 'DFE6E9';
  static const _headerBg = '1A56DB';
  static const _headerText = 'FFFFFF';
  static const _altRowBg = 'F8F9FC';
  static const _greenBg = 'E8F8E8';
  static const _redBg = 'FFE8E8';
  static const _goldBg = 'FFF8E8';

  Future<File> _generateSingleSheet(List<StudentMark> marks, String subject) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final safeName = subject.replaceAll(RegExp(r'[\/\\\?\*\[\]]'), '_');
    final sheet = excel[safeName];

    final first = marks.first;
    final type = first.extractionType;
    final maxMark = first.maxMark;
    final dateStr = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';

    _setColumnWidths(sheet);

    final activeHeaders = ['#', 'Registration No.', 'Student Name', 'Score ($maxMark)', 'Remark'];
    final colCount = activeHeaders.length;

    sheet.appendRow([TextCellValue('SMARTSCAN MARKS')]);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: colCount - 1, rowIndex: 0));
    _styleCell(sheet, 0, 0, bold: true, size: 14, color: _headerText, bg: _primary);
    _setBorder(sheet, 0, 0, colCount - 1, 0);

    sheet.appendRow([TextCellValue('$subject — $type')]);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
        CellIndex.indexByColumnRow(columnIndex: colCount - 1, rowIndex: 1));
    _styleCell(sheet, 1, 0, bold: true, size: 12, color: _darkText, bg: _primaryLight);

    final infoText = 'Date: $dateStr    |    Maximum Mark: $maxMark    |    Total Students: ${marks.length}';
    sheet.appendRow([TextCellValue(infoText)]);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
        CellIndex.indexByColumnRow(columnIndex: colCount - 1, rowIndex: 2));
    _styleCell(sheet, 2, 0, size: 10, color: _mediumText, bg: _white);

    sheet.appendRow([]);

    final headerRowIdx = 4;
    sheet.appendRow(activeHeaders.map((h) => TextCellValue(h)).toList());
    for (int c = 0; c < colCount; c++) {
      _styleCell(sheet, headerRowIdx, c, bold: true, size: 11, color: _headerText, bg: _headerBg);
      _setBorder(sheet, headerRowIdx, c, headerRowIdx, c);
    }

    for (int i = 0; i < marks.length; i++) {
      final m = marks[i];
      final score = double.tryParse(m.mark);
      final isValid = score != null;
      final remark = isValid ? m.remark : '';
      final isEven = i.isEven;

      final rowData = <CellValue?>[
        IntCellValue(i + 1),
        TextCellValue(m.registrationNumber),
        TextCellValue(m.studentName ?? ''),
        isValid ? IntCellValue(score.toInt()) : TextCellValue(m.mark),
        TextCellValue(remark),
      ];
      sheet.appendRow(rowData);

      final rowIdx = headerRowIdx + 1 + i;
      for (int c = 0; c < colCount; c++) {
        final style = CellStyle(
          bold: false,
          fontSize: 11,
          fontColorHex: ExcelColor.fromHexString(_darkText),
          backgroundColorHex: ExcelColor.fromHexString(isEven ? _white : _altRowBg),
        );
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx)).cellStyle = style;
        _setBorder(sheet, rowIdx, c, rowIdx, c);
      }

      if (isValid && remark.isNotEmpty) {
        String? remarkBg;
        if (remark == 'Fail') {
          remarkBg = _redBg;
        } else if (remark == 'Pass') {
          remarkBg = _goldBg;
        } else if (remark == 'Good' || remark == 'Excellent') {
          remarkBg = _greenBg;
        }
        if (remarkBg != null) {
          final idx = CellIndex.indexByColumnRow(columnIndex: colCount - 1, rowIndex: rowIdx);
          sheet.cell(idx).cellStyle = CellStyle(
            bold: true, fontSize: 11,
            fontColorHex: ExcelColor.fromHexString(_darkText),
            backgroundColorHex: ExcelColor.fromHexString(remarkBg),
          );
        }
      }
    }

    final total = marks.length;
    final validScores = marks.map((m) => double.tryParse(m.mark)).where((s) => s != null).cast<double>().toList();
    final passed = validScores.where((s) => s >= maxMark * 0.5).length;
    final failed = validScores.where((s) => s < maxMark * 0.5).length;
    final avg = validScores.isNotEmpty ? validScores.reduce((a, b) => a + b) / validScores.length : 0;

    final summaryStart = headerRowIdx + 1 + total + 1;
    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('SUMMARY')]);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryStart + 1),
        CellIndex.indexByColumnRow(columnIndex: colCount - 1, rowIndex: summaryStart + 1));
    _styleCell(sheet, summaryStart + 1, 0, bold: true, size: 11, color: _headerText, bg: _headerBg);
    _setBorder(sheet, summaryStart + 1, 0, colCount - 1, summaryStart + 1);

    final summaryItems = [
      ['Total Students', total.toString()],
      ['Passed', passed.toString()],
      ['Failed', failed.toString()],
      ['Pass Rate', total > 0 ? '${(passed / total * 100).toStringAsFixed(1)}%' : '-'],
      ['Average Score', validScores.isNotEmpty ? '${avg.toStringAsFixed(1)} / $maxMark' : '-'],
    ];
    for (int i = 0; i < summaryItems.length; i++) {
      final rowIdx = summaryStart + 2 + i;
      sheet.appendRow([TextCellValue(summaryItems[i][0]), TextCellValue(summaryItems[i][1])]);
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx),
          CellIndex.indexByColumnRow(columnIndex: colCount - 1, rowIndex: rowIdx));
      _styleCell(sheet, rowIdx, 0, bold: true, size: 10, color: _darkText, bg: i.isEven ? _white : _altRowBg);
      _styleCell(sheet, rowIdx, 1, bold: false, size: 10, color: _mediumText, bg: i.isEven ? _white : _altRowBg);
      for (int c = 0; c < colCount; c++) {
        _setBorder(sheet, rowIdx, c, rowIdx, c);
      }
    }

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitized = subject.replaceAll(RegExp(r'[^\w\s-]'), '');
    final path = '${directory.path}/${sanitized}_$timestamp.xlsx';
    final file = File(path);
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Excel encoding returned null — platform not supported');
    }
    await file.writeAsBytes(bytes);
    return file;
  }

  void _setColumnWidths(Sheet sheet) {
    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 30);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 14);
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
    buffer.writeln('Subject,$subject');
    buffer.writeln('Total Students,${marks.length}');
    buffer.writeln('');
    buffer.writeln('No,Registration No.,Student Name,Score,Remark');
    for (int i = 0; i < marks.length; i++) {
      final m = marks[i];
      final score = double.tryParse(m.mark);
      final remark = score != null ? m.remark.replaceAll(',', ' ') : '';
      final name = (m.studentName ?? '').replaceAll(',', ' ');
      buffer.writeln('${i + 1},${m.registrationNumber},$name,${m.mark},$remark');
    }
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitized = subject.replaceAll(RegExp(r'[^\w\s-]'), '');
    final path = '${directory.path}/${sanitized}_$timestamp.csv';
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
