import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/teacher_allocation.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final String price;
  final int teacherCount;
  final List<String> features;
  final bool isPopular;

  SubscriptionPlan({required this.id, required this.name, required this.price, this.teacherCount = 1, this.features = const [], this.isPopular = false});
}

class SubscriptionProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  String _currentPlanId = 'basic';
  String? _inviteCode;
  String _institutionName = '';
  int _defaultInviteCredits = 500;
  List<TeacherAllocation> _teachers = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _subscriptionExpiry;

  String get currentPlanId => _currentPlanId;
  String? get inviteCode => _inviteCode;
  String get institutionName => _institutionName;
  int get defaultInviteCredits => _defaultInviteCredits;
  List<TeacherAllocation> get teachers => _teachers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get subscriptionExpiry => _subscriptionExpiry;
  int get teacherCount => _teachers.length;
  int get activeTeacherCount => _teachers.where((t) => t.isActive).length;
  bool get hasLowScanTeachers => _teachers.any((t) => t.isActive && t.isLowOnScans);
  int get maxTeachers => plans.where((p) => p.id == _currentPlanId).firstOrNull?.teacherCount ?? 1;
  bool get canInviteTeachers => _teachers.length < maxTeachers;
  SubscriptionPlan? get currentPlan => plans.where((p) => p.id == _currentPlanId).firstOrNull;

  static List<SubscriptionPlan> plans = [
    SubscriptionPlan(id: 'starter', name: 'Starter', price: 'Tshs 25,000', teacherCount: 2, features: [
      '1,000 scans', 'Up to 2 devices', 'Single image processing', 'Standard Excel export',
    ]),
    SubscriptionPlan(id: 'standard', name: 'Standard', price: 'Tshs 100,000', teacherCount: 5, features: [
      '5,000 scans', 'Up to 5 devices', 'Bulk image processing', 'Enhanced Excel export', 'Subject grouping',
    ]),
    SubscriptionPlan(id: 'institution', name: 'Institution', price: 'Tshs 800,000', teacherCount: 100, features: [
      '50,000 scans', 'Up to 100 devices', 'Bulk image processing', 'Advanced Excel formatting',
      'Subject grouping', 'Invite teachers via code', 'Cloud backup', 'Dedicated support', 'Custom branding',
    ], isPopular: true),
    SubscriptionPlan(id: 'unlimited', name: 'Unlimited', price: 'Tshs 1,300,000', teacherCount: 200, features: [
      '500,000 scans', 'Up to 200 devices', 'Bulk image processing', 'Advanced Excel formatting',
      'Subject grouping', 'Invite teachers via code', 'Cloud backup', 'Dedicated support', 'Custom branding',
    ]),
  ];

  SubscriptionProvider() {
    _load();
  }

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.getSubscriptionStatus();
      if (res['success'] == true && res['subscription'] is Map) {
        final data = res['subscription'] as Map<String, dynamic>;
        _currentPlanId = data['planId'] as String? ?? 'basic';
        _inviteCode = data['inviteCode'] as String?;
        _institutionName = data['institutionName'] as String? ?? '';
        _defaultInviteCredits = (data['defaultInviteCredits'] as int?) ?? 500;
        _subscriptionExpiry = data['subscriptionExpiry'] as String?;

        final teachersData = data['teachers'] as List<dynamic>?;
        if (teachersData != null) {
          _teachers = teachersData.map((t) => TeacherAllocation.fromJson(t as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> joinTeamViaCode(String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.joinTeam(code);
      if (res['success'] == true) {
        await _load();
        return true;
      }
      _errorMessage = 'Invalid or expired code';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> generateInviteCode({String plan = 'starter', int? credits}) async {
    try {
      final res = await _api.generateInviteCode(plan: plan, credits: credits);
      if (res['success'] == true) {
        final code = res['code'] as String;
        _inviteCode = code;
        notifyListeners();
        return code;
      }
    } catch (_) {}
    return null;
  }

  void setInstitutionName(String name) {
    _institutionName = name;
    notifyListeners();
  }

  void setDefaultInviteCredits(int credits) {
    _defaultInviteCredits = credits;
    notifyListeners();
  }

  void selectPlan(String planId) {
    _currentPlanId = planId;
    notifyListeners();
  }

  void allocateScans(int index, int additionalScans) async {
    if (index < 0 || index >= _teachers.length) return;
    final t = _teachers[index];
    _teachers[index] = TeacherAllocation(
      uid: t.uid, email: t.email, name: t.name,
      allocatedScans: t.allocatedScans + additionalScans,
      usedScans: t.usedScans,
      isActive: t.isActive,
    );
    notifyListeners();
    if (t.uid != null) {
      try { await _api.allocateTeamMemberScans(t.uid!, additionalScans); } catch (_) {}
    }
  }

  void removeTeacher(int index) async {
    if (index < 0 || index >= _teachers.length) return;
    final t = _teachers[index];
    _teachers.removeAt(index);
    notifyListeners();
    if (t.uid != null) {
      try { await _api.removeTeamMember(t.uid!); } catch (_) {}
    }
  }

  void toggleTeacherActive(int index) async {
    if (index < 0 || index >= _teachers.length) return;
    final t = _teachers[index];
    final newActive = !t.isActive;
    _teachers[index] = TeacherAllocation(email: t.email, name: t.name, allocatedScans: t.allocatedScans, usedScans: t.usedScans, isActive: newActive, uid: t.uid);
    notifyListeners();
    if (t.uid != null) {
      try { await _api.toggleTeamMemberActive(t.uid!, newActive); } catch (_) {}
    }
  }

  Future<void> refresh() => _load();
}
