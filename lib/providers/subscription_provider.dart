import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/teacher_allocation.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final String price;
  final int teacherCount;
  final List<String> features;
  final bool isPopular;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.teacherCount,
    required this.features,
    this.isPopular = false,
  });
}

class SubscriptionProvider with ChangeNotifier {
  String _currentPlanId = 'basic';
  String? _inviteCode;
  DateTime? _inviteCodeCreatedAt;
  String? _institutionName;
  final List<TeacherAllocation> _teachers = [];
  int _defaultInviteCredits = 500;

  String get currentPlanId => _currentPlanId;
  String? get inviteCode => _inviteCode;
  String? get institutionName => _institutionName;
  List<TeacherAllocation> get teachers => List.unmodifiable(_teachers);
  int get teacherCount => _teachers.length;
  int get activeTeacherCount => _teachers.where((t) => t.isActive).length;

  bool get hasLowScanTeachers => _teachers.any((t) => t.isActive && t.isLowOnScans);
  List<TeacherAllocation> get lowScanTeachers =>
      _teachers.where((t) => t.isActive && t.isLowOnScans).toList();

  static const Duration inviteCodeExpiry = Duration(days: 7);

  int get maxTeachers {
    switch (_currentPlanId) {
      case 'starter': return 2;
      case 'standard': return 5;
      case 'school': return 20;
      case 'institution': return 100;
      case 'unlimited': return 200;
      case 'advanced': return 3;
      case 'premium': return 5;
      default: return 1;
    }
  }

  bool get canInviteTeachers =>
      _currentPlanId != 'basic' && _teachers.length < maxTeachers - 1;

  int get defaultInviteCredits => _defaultInviteCredits;

  void setDefaultInviteCredits(int credits) {
    _defaultInviteCredits = credits;
    _saveSubscription();
    notifyListeners();
  }

  void setInstitutionName(String name) {
    _institutionName = name;
    _saveSubscription();
    notifyListeners();
  }

  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(id: 'basic', name: 'Basic', price: 'Free', teacherCount: 1, features: [
      'Single teacher access', '50 extractions per month', 'Single image processing',
      'Standard Excel export', 'Subject grouping',
    ]),
    SubscriptionPlan(id: 'starter', name: 'Starter', price: 'Tshs 25,000', teacherCount: 2, features: [
      'Up to 2 teachers', '1,000 scans', 'Single image processing', 'Standard Excel export', 'Subject grouping',
    ]),
    SubscriptionPlan(id: 'standard', name: 'Standard', price: 'Tshs 100,000', teacherCount: 5, features: [
      'Up to 5 teachers', '5,000 scans', 'Bulk image processing', 'Enhanced Excel export',
      'Subject grouping', 'Priority support',
    ]),
    SubscriptionPlan(id: 'school', name: 'School', price: 'Tshs 180,000', teacherCount: 20, features: [
      'Up to 20 teachers', '10,000 scans', 'Bulk image processing', 'Advanced Excel formatting',
      'Subject grouping', 'Cloud backup', 'Priority support',
    ], isPopular: true),
    SubscriptionPlan(id: 'institution', name: 'Institution', price: 'Tshs 800,000', teacherCount: 100, features: [
      'Up to 100 teachers', '50,000 scans', 'Bulk image processing', 'Advanced Excel formatting',
      'Subject grouping', 'Invite teachers via code', 'Cloud backup', 'Dedicated support', 'Custom branding',
    ]),
    SubscriptionPlan(id: 'unlimited', name: 'Unlimited', price: 'Tshs 1,300,000', teacherCount: 200, features: [
      'Up to 200 teachers', 'Unlimited scans', 'Bulk image processing', 'Advanced Excel formatting',
      'Subject grouping', 'Invite teachers via code', 'Cloud backup', 'Dedicated support', 'Custom branding',
    ]),
  ];

  SubscriptionProvider() {
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    _currentPlanId = prefs.getString('subscription_plan') ?? 'basic';
    _inviteCode = prefs.getString('invite_code');
    _defaultInviteCredits = prefs.getInt('default_invite_credits') ?? 500;
    _institutionName = prefs.getString('institution_name');
    final createdAtStr = prefs.getString('invite_code_created_at');
    _inviteCodeCreatedAt = createdAtStr != null ? DateTime.parse(createdAtStr) : null;
    final teachersRaw = prefs.getString('teacher_allocations');
    if (teachersRaw != null && teachersRaw.isNotEmpty) {
      _teachers.addAll(TeacherAllocation.decodeList(teachersRaw));
    }
    notifyListeners();
  }

  Future<void> _saveSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscription_plan', _currentPlanId);
    await prefs.setInt('default_invite_credits', _defaultInviteCredits);
    if (_institutionName != null) {
      await prefs.setString('institution_name', _institutionName!);
    } else {
      await prefs.remove('institution_name');
    }
    if (_inviteCode != null) {
      await prefs.setString('invite_code', _inviteCode!);
      await prefs.setInt('invite_code_credits_$_inviteCode', _defaultInviteCredits);
      await prefs.setString('invite_code_created_at', DateTime.now().toIso8601String());
    } else {
      await prefs.remove('invite_code');
      await prefs.remove('invite_code_created_at');
    }
    final encoded = TeacherAllocation.encodeList(_teachers);
    await prefs.setString('teacher_allocations', encoded);
  }

  SubscriptionPlan? get currentPlan {
    try {
      return plans.firstWhere((p) => p.id == _currentPlanId);
    } catch (_) {
      return plans.first;
    }
  }

  bool validateInviteCode(String code) {
    if (_currentPlanId == 'basic') return false;
    if (_teachers.length >= maxTeachers - 1) return false;
    if (_inviteCode == null || code != _inviteCode) return false;
    if (_inviteCodeCreatedAt != null &&
        DateTime.now().difference(_inviteCodeCreatedAt!) > inviteCodeExpiry) {
      return false;
    }
    return true;
  }

  void consumeInviteCode(String code, String teacherName) {
    if (!validateInviteCode(code)) return;
    _teachers.add(TeacherAllocation(
      email: 'teacher_${DateTime.now().millisecondsSinceEpoch}@temp.com',
      name: teacherName,
      allocatedScans: _defaultInviteCredits,
      usedScans: 0,
      isActive: true,
      institutionName: _institutionName,
      packageId: _currentPlanId,
    ));
    _saveSubscription();
    notifyListeners();
    LoggerService.instance.logInviteRedeemed(code, teacherName);
  }

  void generateInviteCode() {
    if (ApiConfig.useApi) {
      _generateFromApi();
    } else {
      _generateLocalCode();
    }
  }

  Future<void> _generateFromApi() async {
    try {
      final result = await ApiService().teamInvite();
      _inviteCode = result['code'] as String;
      _saveSubscription();
      notifyListeners();
    } catch (_) {
      _generateLocalCode();
    }
  }

  void _generateLocalCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    _inviteCode = List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
    _inviteCodeCreatedAt = DateTime.now();
    _saveSubscription();
    notifyListeners();
    LoggerService.instance.logInviteGenerated(_inviteCode!);
  }

  void allocateScans(int index, int count) {
    if (index < 0 || index >= _teachers.length) return;
    _teachers[index] = _teachers[index].copyWith(allocatedScans: count, usedScans: 0);
    _saveSubscription();
    notifyListeners();
  }

  void deactivateTeacher(int index) {
    if (index < 0 || index >= _teachers.length) return;
    _teachers[index] = _teachers[index].copyWith(isActive: false);
    _saveSubscription();
    notifyListeners();
  }

  void reactivateTeacher(int index) {
    if (index < 0 || index >= _teachers.length) return;
    _teachers[index] = _teachers[index].copyWith(isActive: true);
    _saveSubscription();
    notifyListeners();
  }

  void toggleTeacherActive(int index) {
    if (index < 0 || index >= _teachers.length) return;
    _teachers[index] = _teachers[index].copyWith(isActive: !_teachers[index].isActive);
    _saveSubscription();
    notifyListeners();
  }

  void removeTeacher(int index) {
    if (index < 0 || index >= _teachers.length) return;
    _teachers.removeAt(index);
    _saveSubscription();
    notifyListeners();
  }

  void recordScanUsage(String teacherEmail) {
    final idx = _teachers.indexWhere((t) => t.email == teacherEmail);
    if (idx < 0) return;
    _teachers[idx] = _teachers[idx].copyWith(usedScans: _teachers[idx].usedScans + 1);
    _saveSubscription();
    notifyListeners();
  }

  void selectPlan(String planId) {
    _currentPlanId = planId;
    if (planId == 'basic') {
      _teachers.clear();
      _inviteCode = null;
      _institutionName = null;
    }
    _saveSubscription();
    if (ApiConfig.useApi && planId != 'basic') {
      unawaited(ApiService().purchasePlan(planId).catchError((_) => <String, dynamic>{}));
    }
    notifyListeners();
  }

  void resetInviteCode() {
    _inviteCode = null;
    _inviteCodeCreatedAt = null;
    _saveSubscription();
    notifyListeners();
  }

  bool tryAddTeacher(String code) {
    if (_currentPlanId == 'basic') return false;
    if (_teachers.length >= maxTeachers - 1) return false;
    if (_inviteCode == null || code != _inviteCode) return false;
    _teachers.add(TeacherAllocation(
      email: 'teacher_${DateTime.now().millisecondsSinceEpoch}@temp.com',
      name: 'Teacher ${_teachers.length + 1}',
      allocatedScans: _defaultInviteCredits,
    ));
    _inviteCode = null;
    _saveSubscription();
    notifyListeners();
    return true;
  }
}
