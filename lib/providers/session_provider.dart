import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/extraction_session.dart';
import '../models/student_mark.dart';
import '../services/database_service.dart';

class SessionProvider with ChangeNotifier {
  List<ExtractionSession> _sessions = [];
  String? _activeSessionId;
  Timer? _debounceTimer;
  final _db = DatabaseService();

  List<ExtractionSession> get sessions => List.unmodifiable(_sessions);
  String? get activeSessionId => _activeSessionId;
  ExtractionSession? get activeSession =>
      _sessions.where((s) => s.id == _activeSessionId).firstOrNull;
  List<String> get sessionNames => _sessions.map((s) => s.name).toList();

  SessionProvider() {
    _load();
  }

  @override
  Future<void> dispose() async {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await _db.getAllSessions();
      _sessions = [];
      for (final row in rows) {
        final marksRows = await _db.getMarksForSession(row['id'] as String);
        final marks = marksRows.map((m) => StudentMark(
          registrationNumber: m['registration_number'] as String,
          mark: m['mark'] as String,
          studentName: m['student_name'] as String?,
          subject: m['subject'] as String,
          extractedAt: DateTime.parse(m['extracted_at'] as String),
          extractionType: m['extraction_type'] as String,
          maxMark: m['max_mark'] as int,
        )).toList();

        _sessions.add(ExtractionSession(
          id: row['id'] as String,
          name: row['name'] as String,
          course: row['course'] as String,
          extractionType: row['extraction_type'] as String,
          maxMark: row['max_mark'] as int,
          createdAt: DateTime.parse(row['created_at'] as String),
          marks: marks,
        ));
      }

      final prefs = await SharedPreferences.getInstance();
      _activeSessionId = prefs.getString('active_session_id');
    } catch (_) {
      _sessions = [];
    }
    notifyListeners();
  }

  Future<void> _saveActiveSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    if (_activeSessionId != null) {
      await prefs.setString('active_session_id', _activeSessionId!);
    } else {
      await prefs.remove('active_session_id');
    }
  }

  ExtractionSession? getSessionById(String id) {
    return _sessions.where((s) => s.id == id).firstOrNull;
  }

  List<ExtractionSession> getSessionsForCourse(String course) {
    return _sessions.where((s) => s.course == course).toList();
  }

  Future<List<StudentMark>> getMarksForSession(String id) async {
    final marksRows = await _db.getMarksForSession(id);
    return marksRows.map((m) => StudentMark(
      registrationNumber: m['registration_number'] as String,
      mark: m['mark'] as String,
      studentName: m['student_name'] as String?,
      subject: m['subject'] as String,
      extractedAt: DateTime.parse(m['extracted_at'] as String),
      extractionType: m['extraction_type'] as String,
      maxMark: m['max_mark'] as int,
    )).toList();
  }

  Future<String> createSession({
    required String name,
    required String course,
    required String extractionType,
    required int maxMark,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now().toIso8601String();
    await _db.insertSession({
      'id': id,
      'name': name,
      'course': course,
      'extraction_type': extractionType,
      'max_mark': maxMark,
      'created_at': now,
    });
    final session = ExtractionSession(
      id: id,
      name: name,
      course: course,
      extractionType: extractionType,
      maxMark: maxMark,
      createdAt: DateTime.parse(now),
    );
    _sessions.add(session);
    _activeSessionId = session.id;
    notifyListeners();
    await _saveActiveSessionId();
    return session.id;
  }

  Future<void> selectSession(String? id) async {
    _activeSessionId = id;
    notifyListeners();
    await _saveActiveSessionId();
  }

  Future<void> renameSession(String id, String newName) async {
    final idx = _sessions.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    _sessions[idx] = _sessions[idx].copyWith(name: newName);
    await _db.updateSession(id, {'name': newName});
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    if (_activeSessionId == id) {
      _activeSessionId = _sessions.isNotEmpty ? _sessions.last.id : null;
    }
    await _db.deleteSession(id);
    notifyListeners();
    await _saveActiveSessionId();
  }

  Future<void> addMarksToSession(String id, List<StudentMark> marks) async {
    final idx = _sessions.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final markRows = marks.map((m) => {
      'registration_number': m.registrationNumber,
      'student_name': m.studentName,
      'mark': m.mark,
      'subject': m.subject,
      'extraction_type': m.extractionType,
      'max_mark': m.maxMark,
      'extracted_at': m.extractedAt.toIso8601String(),
    }).toList();
    await _db.insertMarks(id, markRows);
    final updated = List<StudentMark>.from(_sessions[idx].marks)..addAll(marks);
    _sessions[idx] = _sessions[idx].copyWith(marks: updated);
    notifyListeners();
  }

  Future<void> clearSessionMarks(String id) async {
    final idx = _sessions.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    await _db.clearMarksForSession(id);
    _sessions[idx] = _sessions[idx].copyWith(marks: []);
    notifyListeners();
  }

  Future<void> editSessionMeta(String id, {String? extractionType, int? maxMark}) async {
    final idx = _sessions.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final updates = <String, dynamic>{};
    if (extractionType != null) updates['extraction_type'] = extractionType;
    if (maxMark != null) updates['max_mark'] = maxMark;
    if (updates.isNotEmpty) await _db.updateSession(id, updates);
    _sessions[idx] = _sessions[idx].copyWith(
      extractionType: extractionType,
      maxMark: maxMark,
    );
    notifyListeners();
  }

  Future<void> updateMarkInSession(String sessionId, int markIndex, StudentMark updated) async {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;
    _sessions[idx] = _sessions[idx].updateMark(markIndex, updated);
    notifyListeners();
  }

  List<String> get courses => _sessions.map((s) => s.course).toSet().toList()..sort();
}
