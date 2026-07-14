import 'package:excel/excel.dart';

class StudentMark {
  final String registrationNumber;
  final String mark;
  final String? studentName;
  final String subject;
  final DateTime extractedAt;
  final String extractionType;
  final int maxMark;

  StudentMark({
    required this.registrationNumber,
    required this.mark,
    this.studentName,
    required this.subject,
    required this.extractedAt,
    this.extractionType = 'Exam',
    this.maxMark = 100,
  });

  String get remark {
    final score = double.tryParse(mark);
    if (score == null) return '';
    final percentage = maxMark > 0 ? score / maxMark : 0;
    if (percentage >= 0.5 && score >= maxMark * 0.5) return 'Pass';
    if (percentage >= 0.75) return 'Excellent';
    if (percentage >= 0.5) return 'Good';
    return 'Fail';
  }

  Map<String, dynamic> toJson() {
    return {
      'registrationNumber': registrationNumber,
      'mark': mark,
      'studentName': studentName,
      'subject': subject,
      'extractedAt': extractedAt.toIso8601String(),
      'extractionType': extractionType,
      'maxMark': maxMark,
    };
  }

  factory StudentMark.fromJson(Map<String, dynamic> json) {
    return StudentMark(
      registrationNumber: json['registrationNumber'],
      mark: json['mark'],
      studentName: json['studentName'],
      subject: json['subject'] ?? 'General',
      extractedAt: DateTime.parse(json['extractedAt']),
      extractionType: json['extractionType'] ?? 'Exam',
      maxMark: json['maxMark'] ?? 100,
    );
  }

  List<CellValue?> toExcelRow() {
    return [
      TextCellValue(studentName ?? ''),
      TextCellValue(registrationNumber),
      TextCellValue(mark),
    ];
  }

  StudentMark copyWith({
    String? registrationNumber,
    String? mark,
    String? studentName,
    String? subject,
    DateTime? extractedAt,
    String? extractionType,
    int? maxMark,
  }) {
    return StudentMark(
      registrationNumber: registrationNumber ?? this.registrationNumber,
      mark: mark ?? this.mark,
      studentName: studentName ?? this.studentName,
      subject: subject ?? this.subject,
      extractedAt: extractedAt ?? this.extractedAt,
      extractionType: extractionType ?? this.extractionType,
      maxMark: maxMark ?? this.maxMark,
    );
  }
}
