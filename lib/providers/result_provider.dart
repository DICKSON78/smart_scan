import 'package:flutter/foundation.dart';
import '../models/student_mark.dart';

class ResultProvider with ChangeNotifier {
  final Map<String, List<StudentMark>> _resultsBySubject = {};
  List<String> _recentSubjects = [];
  static const List<String> commonSubjects = [
    'Mathematics',
    'English',
    'Physics',
    'Chemistry',
    'Biology',
    'History',
    'Geography',
    'Computer Science',
    'Economics',
    'Accounting',
    'Business Studies',
    'Kiswahili',
    'French',
    'Religious Studies',
    'Agriculture',
    'Science',
  ];

  ResultProvider();

  List<StudentMark> getResultsForSubject(String subject) {
    return _resultsBySubject[subject] ?? [];
  }

  void addResults(String subject, List<StudentMark> marks) {
    _resultsBySubject.putIfAbsent(subject, () => []);
    _resultsBySubject[subject]!.addAll(marks);

    if (!_recentSubjects.contains(subject)) {
      _recentSubjects.insert(0, subject);
      if (_recentSubjects.length > 20) {
        _recentSubjects = _recentSubjects.sublist(0, 20);
      }
    }

    notifyListeners();
  }

  void clearResultsForSubject(String subject) {
    _resultsBySubject.remove(subject);
    notifyListeners();
  }

  void clearAllResults() {
    _resultsBySubject.clear();
    notifyListeners();
  }
}
