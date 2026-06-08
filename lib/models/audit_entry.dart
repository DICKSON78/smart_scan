class AuditEntry {
  final String id;
  final DateTime timestamp;
  final String action;
  final String details;
  final String? studentId;
  final String? oldValue;
  final String? newValue;

  AuditEntry({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.details,
    this.studentId,
    this.oldValue,
    this.newValue,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'action': action,
    'details': details,
    'studentId': studentId,
    'oldValue': oldValue,
    'newValue': newValue,
  };

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    id: json['id'],
    timestamp: DateTime.parse(json['timestamp']),
    action: json['action'],
    details: json['details'],
    studentId: json['studentId'],
    oldValue: json['oldValue'],
    newValue: json['newValue'],
  );
}
