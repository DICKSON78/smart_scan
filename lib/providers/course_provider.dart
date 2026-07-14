import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class UniversityCourse {
  final String code;
  final String name;
  const UniversityCourse({required this.code, required this.name});

  String get display => '$code - $name';

  Map<String, dynamic> toJson() => {'code': code, 'name': name};

  factory UniversityCourse.fromJson(Map<String, dynamic> json) =>
      UniversityCourse(code: json['code'] as String? ?? '', name: json['name'] as String? ?? '');
}

class CourseProvider with ChangeNotifier {
  final List<UniversityCourse> _courses = [];
  String _currentCourse = '';

  List<UniversityCourse> get courses => _courses;
  String get currentCourse => _currentCourse;
  List<String> get courseDisplays => _courses.map((c) => c.display).toList();

  CourseProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().listCourses();
      if (res['success'] == true && res['courses'] is List) {
        _courses.clear();
        for (final c in res['courses'] as List) {
          final data = c as Map<String, dynamic>;
          _courses.add(UniversityCourse(code: data['code'] as String? ?? '', name: data['name'] as String? ?? ''));
        }
        notifyListeners();
        return;
      }
    } catch (_) {}

    // Fallback: load from local storage
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('courses');
    if (stored != null) {
      final list = stored.split(',').where((s) => s.isNotEmpty);
      _courses.clear();
      for (final entry in list) {
        final parts = entry.split('|');
        if (parts.length == 2) _courses.add(UniversityCourse(code: parts[0], name: parts[1]));
      }
      notifyListeners();
    }
  }

  Future<bool> addCourse(String code, String name) async {
    try {
      final res = await ApiService().createCourse(code, name);
      if (res['success'] == true) {
        _courses.add(UniversityCourse(code: code.toUpperCase(), name: name));
        notifyListeners();
        await _saveLocal();
        return true;
      }
    } catch (_) {}
    return false;
  }

  void removeCourse(int index) {
    if (index < 0 || index >= _courses.length) return;
    _courses.removeAt(index);
    notifyListeners();
    _saveLocal();
  }

  void setCurrentCourse(String code) {
    _currentCourse = code;
    notifyListeners();
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _courses.map((c) => '${c.code}|${c.name}').join(',');
    await prefs.setString('courses', data);
  }
}
