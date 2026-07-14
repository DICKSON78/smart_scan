import 'dart:convert';

class TeacherAllocation {
  final String? uid;
  final String email;
  final String name;
  int allocatedScans;
  int usedScans;
  bool isActive;
  String? institutionName;
  String? packageId;
  DateTime addedAt;

  TeacherAllocation({
    this.uid,
    required this.email,
    required this.name,
    this.allocatedScans = 0,
    this.usedScans = 0,
    this.isActive = true,
    this.institutionName,
    this.packageId,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  int get remainingScans => (allocatedScans - usedScans).clamp(0, allocatedScans);
  double get usagePercent => allocatedScans > 0 ? usedScans / allocatedScans : 0.0;
  bool get isLowOnScans => allocatedScans > 0 && remainingScans <= (allocatedScans * 0.2).round();

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'name': name,
    'allocatedScans': allocatedScans,
    'usedScans': usedScans,
    'isActive': isActive,
    'institutionName': institutionName,
    'packageId': packageId,
    'addedAt': addedAt.toIso8601String(),
  };

  factory TeacherAllocation.fromJson(Map<String, dynamic> json) => TeacherAllocation(
    uid: json['uid'] as String?,
    email: json['email'] as String,
    name: json['name'] as String,
    allocatedScans: json['allocatedScans'] as int? ?? 0,
    usedScans: json['usedScans'] as int? ?? 0,
    isActive: json['isActive'] as bool? ?? true,
    institutionName: json['institutionName'] as String?,
    packageId: json['packageId'] as String?,
    addedAt: json['addedAt'] != null ? DateTime.parse(json['addedAt'] as String) : null,
  );

  TeacherAllocation copyWith({
    String? uid,
    String? email,
    String? name,
    int? allocatedScans,
    int? usedScans,
    bool? isActive,
    String? institutionName,
    String? packageId,
    DateTime? addedAt,
  }) => TeacherAllocation(
    uid: uid ?? this.uid,
    email: email ?? this.email,
    name: name ?? this.name,
    allocatedScans: allocatedScans ?? this.allocatedScans,
    usedScans: usedScans ?? this.usedScans,
    isActive: isActive ?? this.isActive,
    institutionName: institutionName ?? this.institutionName,
    packageId: packageId ?? this.packageId,
    addedAt: addedAt ?? this.addedAt,
  );

  static String encodeList(List<TeacherAllocation> list) =>
    jsonEncode(list.map((t) => t.toJson()).toList());

  static List<TeacherAllocation> decodeList(String raw) {
    final list = jsonDecode(raw) as List;
    return list.map((e) => TeacherAllocation.fromJson(e as Map<String, dynamic>)).toList();
  }
}
