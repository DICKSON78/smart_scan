import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';

class UniversityCourse {
  final String code;
  final String name;
  const UniversityCourse({required this.code, required this.name});

  String get display => '$code - $name';

  Map<String, dynamic> toJson() => {'code': code, 'name': name};

  factory UniversityCourse.fromJson(Map<String, dynamic> json) =>
      UniversityCourse(code: json['code'], name: json['name']);
}

class CourseProvider with ChangeNotifier {
  final List<UniversityCourse> _courses = [];
  String _currentCourse = '';

  List<UniversityCourse> get courses => _courses;
  String get currentCourse => _currentCourse;
  List<String> get courseDisplays =>
      _courses.map((c) => c.display).toList();

  CourseProvider();

  void setCurrentCourse(String course) {
    _currentCourse = course;
    notifyListeners();
  }

  void addCourse(String code, String name) {
    final existing =
        _courses.where((c) => c.code.toUpperCase() == code.toUpperCase());
    if (existing.isNotEmpty) return;
    _courses.add(UniversityCourse(code: code.toUpperCase(), name: name));
    _saveCourses();
    if (ApiConfig.useApi) {
      unawaited(ApiService().createCourse(code, name).catchError((_) => <String, dynamic>{}));
    }
    notifyListeners();
  }

  void removeCourse(int index) {
    if (index >= 0 && index < _courses.length) {
      _courses.removeAt(index);
      _saveCourses();
      if (ApiConfig.useApi) {
        unawaited(ApiService().deleteCourse(index + 1).catchError((_) => <String, dynamic>{}));
      }
      notifyListeners();
    }
  }

  Future<void> _saveCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(_courses.map((c) => c.toJson()).toList());
    await prefs.setString('university_courses', jsonStr);
  }
}
