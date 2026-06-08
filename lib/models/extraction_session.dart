import 'student_mark.dart';

class ExtractionSession {
  final String id;
  String name;
  final String course;
  final String extractionType;
  final int maxMark;
  final DateTime createdAt;
  final List<StudentMark> marks;

  ExtractionSession({
    required this.id,
    required this.name,
    required this.course,
    required this.extractionType,
    required this.maxMark,
    required this.createdAt,
    List<StudentMark>? marks,
  }) : marks = marks ?? [];

  int get markCount => marks.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'course': course,
    'extractionType': extractionType,
    'maxMark': maxMark,
    'createdAt': createdAt.toIso8601String(),
    'marks': marks.map((m) => m.toJson()).toList(),
  };

  factory ExtractionSession.fromJson(Map<String, dynamic> json) => ExtractionSession(
    id: json['id'],
    name: json['name'],
    course: json['course'],
    extractionType: json['extractionType'] ?? 'Exam',
    maxMark: json['maxMark'] ?? 100,
    createdAt: DateTime.parse(json['createdAt']),
    marks: (json['marks'] as List?)?.map((e) => StudentMark.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );

  ExtractionSession copyWith({
    String? name,
    String? extractionType,
    int? maxMark,
    List<StudentMark>? marks,
  }) {
    return ExtractionSession(
      id: id,
      name: name ?? this.name,
      course: course,
      extractionType: extractionType ?? this.extractionType,
      maxMark: maxMark ?? this.maxMark,
      createdAt: createdAt,
      marks: marks ?? List.from(this.marks),
    );
  }

  ExtractionSession updateMark(int index, StudentMark updated) {
    final newMarks = List<StudentMark>.from(marks);
    if (index >= 0 && index < newMarks.length) {
      newMarks[index] = updated;
    }
    return copyWith(marks: newMarks);
  }
}
