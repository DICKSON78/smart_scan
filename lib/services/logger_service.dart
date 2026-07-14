import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogEvent {
  final String type;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  LogEvent({
    required this.type,
    required this.message,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type,
    'message': message,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
  };
}

class LoggerService {
  static final LoggerService _instance = LoggerService._();
  static LoggerService get instance => _instance;
  LoggerService._();

  List<LogEvent> _events = [];
  File? _logFile;
  final List<LogEvent> _pendingWrites = [];
  Timer? _flushTimer;
  static const int _batchSize = 10;
  static const Duration _flushInterval = Duration(seconds: 5);

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${dir.path}/logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    _logFile = File('${logsDir.path}/events_${DateTime.now().millisecondsSinceEpoch}.log');
    _events = [];
  }

  Future<void> _write(LogEvent event) async {
    _events.add(event);
    _pendingWrites.add(event);
    if (_pendingWrites.length >= _batchSize) {
      await _flushPending();
    } else {
      _flushTimer ??= Timer(_flushInterval, () => _flushPending());
    }
  }

  Future<void> _flushPending() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pendingWrites.isEmpty || _logFile == null) return;
    final batch = _pendingWrites.map((e) => jsonEncode(e.toJson())).join('\n') + '\n';
    _pendingWrites.clear();
    try {
      await _logFile!.writeAsString(batch, mode: FileMode.append);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _flushPending();
  }

  Future<void> logInviteGenerated(String code) => _write(LogEvent(
    type: 'INVITE_GENERATED',
    message: 'Invite code $code generated',
    data: {'code': code},
  ));

  Future<void> logInviteRedeemed(String code, String teacherName) => _write(LogEvent(
    type: 'INVITE_REDEEMED',
    message: 'Teacher $teacherName redeemed code $code',
    data: {'code': code, 'teacherName': teacherName},
  ));

  Future<void> logCreditsAllocated(String teacherName, int amount) => _write(LogEvent(
    type: 'CREDITS_ALLOCATED',
    message: 'Allocated $amount credits to $teacherName',
    data: {'teacherName': teacherName, 'amount': amount},
  ));

  Future<void> logCreditsDeducted(int amount, int remaining) => _write(LogEvent(
    type: 'CREDITS_DEDUCTED',
    message: 'Deducted $amount credits ($remaining remaining)',
    data: {'amount': amount, 'remaining': remaining},
  ));

  Future<void> logExportSuccess(String format, String subject, int count) => _write(LogEvent(
    type: 'EXPORT_SUCCESS',
    message: 'Exported $count marks for $subject as $format',
    data: {'format': format, 'subject': subject, 'count': count},
  ));

  Future<void> logExportFailure(String format, String subject, String error) => _write(LogEvent(
    type: 'EXPORT_FAILURE',
    message: 'Export failed: $error',
    data: {'format': format, 'subject': subject, 'error': error},
  ));

  Future<void> logRegistration(String name, String email) => _write(LogEvent(
    type: 'REGISTRATION',
    message: 'User registered',
    data: {},
  ));

  Future<void> logExtraction(String subject, int imageCount, int marksCount) => _write(LogEvent(
    type: 'EXTRACTION',
    message: 'Extracted $marksCount marks from $imageCount images for $subject',
    data: {'subject': subject, 'imageCount': imageCount, 'marksCount': marksCount},
  ));

  Future<void> logError(String context, String error) => _write(LogEvent(
    type: 'ERROR',
    message: 'Error in $context: $error',
    data: {'context': context, 'error': error},
  ));

  List<LogEvent> getEvents({String? type}) {
    if (type == null) return List.unmodifiable(_events);
    return _events.where((e) => e.type == type).toList();
  }

  Future<String> exportLogs() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/logs/export_${DateTime.now().millisecondsSinceEpoch}.json');
    final data = _events.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(data));
    return file.path;
  }

  void clear() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingWrites.clear();
    _events.clear();
    _logFile = null;
  }
}
