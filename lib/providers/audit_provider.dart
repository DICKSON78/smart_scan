import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/audit_entry.dart';

class AuditProvider extends ChangeNotifier {
  static const _key = 'audit_logs';
  List<AuditEntry> _logs = [];
  List<AuditEntry> get logs => List.unmodifiable(_logs);

  AuditProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _logs = list.map((e) => AuditEntry.fromJson(e as Map<String, dynamic>)).toList();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_logs.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  Future<void> addEntry(AuditEntry entry) async {
    _logs.insert(0, entry);
    notifyListeners();
    await _save();
  }

  Future<void> logExtraction(String details, {String? studentId}) async {
    await addEntry(AuditEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      action: 'EXTRACT',
      details: details,
      studentId: studentId,
    ));
  }

  Future<void> logEdit(String details, {String? studentId, String? oldValue, String? newValue}) async {
    await addEntry(AuditEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      action: 'EDIT',
      details: details,
      studentId: studentId,
      oldValue: oldValue,
      newValue: newValue,
    ));
  }

  Future<void> logDelete(String details, {String? studentId}) async {
    await addEntry(AuditEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      action: 'DELETE',
      details: details,
      studentId: studentId,
    ));
  }

  void clear() {
    _logs.clear();
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) => prefs.remove(_key));
  }
}
