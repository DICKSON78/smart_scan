import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'exam_mark_extractor.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            course TEXT NOT NULL,
            extraction_type TEXT NOT NULL DEFAULT 'Exam',
            max_mark INTEGER NOT NULL DEFAULT 100,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE marks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            registration_number TEXT NOT NULL,
            student_name TEXT,
            mark TEXT NOT NULL DEFAULT 'N/A',
            subject TEXT NOT NULL DEFAULT 'General',
            extraction_type TEXT NOT NULL DEFAULT 'Exam',
            max_mark INTEGER NOT NULL DEFAULT 100,
            extracted_at TEXT NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_marks_session ON marks(session_id)');
        await db.execute(
            'CREATE INDEX idx_sessions_course ON sessions(course)');
      },
    );
  }

  // ---- Sessions ----

  Future<Map<String, dynamic>?> getSession(String id) async {
    final db = await database;
    final rows = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getAllSessions() async {
    final db = await database;
    return db.query('sessions', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getSessionsForCourse(
      String course) async {
    final db = await database;
    return db.query('sessions',
        where: 'course = ?', whereArgs: [course], orderBy: 'created_at DESC');
  }

  Future<void> insertSession(Map<String, dynamic> session) async {
    final db = await database;
    await db.insert('sessions', {
      'id': session['id'],
      'name': session['name'],
      'course': session['course'],
      'extraction_type': session['extraction_type'],
      'max_mark': session['max_mark'],
      'created_at': session['created_at'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSession(
      String id, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update('sessions', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete('marks', where: 'session_id = ?', whereArgs: [id]);
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Marks ----

  Future<List<Map<String, dynamic>>> getMarksForSession(
      String sessionId) async {
    final db = await database;
    return db.query('marks',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'rowid ASC');
  }

  Future<int> insertMark(Map<String, dynamic> mark) async {
    final db = await database;
    return db.insert('marks', {
      'session_id': mark['session_id'],
      'registration_number': mark['registration_number'],
      'student_name': mark['student_name'],
      'mark': mark['mark'],
      'subject': mark['subject'],
      'extraction_type': mark['extraction_type'],
      'max_mark': mark['max_mark'],
      'extracted_at': mark['extracted_at'],
    });
  }

  Future<void> insertMarks(
      String sessionId, List<Map<String, dynamic>> marks) async {
    final db = await database;
    final batch = db.batch();
    for (final mark in marks) {
      batch.insert('marks', {
        'session_id': sessionId,
        'registration_number': mark['registration_number'],
        'student_name': mark['student_name'],
        'mark': mark['mark'],
        'subject': mark['subject'],
        'extraction_type': mark['extraction_type'],
        'max_mark': mark['max_mark'],
        'extracted_at': mark['extracted_at'],
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateMark(int markId, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update('marks', updates, where: 'id = ?', whereArgs: [markId]);
  }

  Future<void> clearMarksForSession(String sessionId) async {
    final db = await database;
    await db.delete('marks',
        where: 'session_id = ?', whereArgs: [sessionId]);
  }

  Future<void> deleteMark(int markId) async {
    final db = await database;
    await db.delete('marks', where: 'id = ?', whereArgs: [markId]);
  }

  // ---- Course-based mark queries (for ResultProvider) ----

  Future<List<Map<String, dynamic>>> getMarksForCourse(
      String course) async {
    final db = await database;
    return db.rawQuery('''
      SELECT m.* FROM marks m
      INNER JOIN sessions s ON s.id = m.session_id
      WHERE s.course = ?
      ORDER BY m.rowid DESC
    ''', [course]);
  }

  Future<List<Map<String, dynamic>>> getMarksGroupedBySubject(
      String course) async {
    final db = await database;
    return db.rawQuery('''
      SELECT m.* FROM marks m
      INNER JOIN sessions s ON s.id = m.session_id
      WHERE s.course = ?
      ORDER BY m.subject, m.rowid ASC
    ''', [course]);
  }

  // ---- Utility ----

  Future<int> getMarkCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM marks');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('marks');
    await db.delete('sessions');
  }
}
