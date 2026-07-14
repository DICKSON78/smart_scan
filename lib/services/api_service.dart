import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Map<String, dynamic> _docToMap(DocumentSnapshot doc) =>
      {'id': doc.id, ...doc.data() as Map<String, dynamic>};

  Future<Map<String, dynamic>> deductCredits({int count = 1}) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final doc = await _db.collection('users').doc(uid).get();
    final current = (doc.data()?['credits'] as num?)?.toInt() ?? 0;
    if (current < count) throw Exception('Insufficient credits');
    await _db.collection('users').doc(uid).update({
      'credits': FieldValue.increment(-count),
    });
    return {'success': true};
  }

  Future<Map<String, dynamic>> getCreditsBalance() async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('User not found');
    final user = doc.data()!;
    return {'success': true, 'credits': (user['credits'] as num?)?.toInt() ?? 0};
  }

  Future<Map<String, dynamic>> getMyUsage() async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('User not found');
    final user = doc.data()!;
    if (user['isAdmin'] == true || user['parentAdminId'] == null) {
      return {'success': true, 'isTeacher': false, 'creditsRemaining': (user['credits'] as num?)?.toInt() ?? 0};
    }
    final alloc = await _db.collection('teachers')
      .where('userId', isEqualTo: uid)
      .where('adminId', isEqualTo: user['parentAdminId'])
      .limit(1)
      .get();
    if (alloc.docs.isEmpty) {
      return {'success': true, 'isTeacher': true, 'allocatedCredits': 0, 'usedCredits': 0};
    }
    final d = alloc.docs.first.data();
    return {
      'success': true, 'isTeacher': true,
      'allocatedCredits': (d['allocatedCredits'] as num?)?.toInt() ?? 0,
      'usedCredits': (d['usedCredits'] as num?)?.toInt() ?? 0,
    };
  }

  Future<Map<String, dynamic>> joinTeam(String code) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final codeSnap = await _db.collection('invite_codes').doc(code.toUpperCase()).get();
    if (!codeSnap.exists) throw Exception('Invalid invite code');
    final invite = codeSnap.data()!;
    if (invite['usedBy'] != null) throw Exception('Invite code has already been used');

    final adminDoc = await _db.collection('users').doc(invite['adminId'] as String).get();
    if (!adminDoc.exists) throw Exception('Admin not found');
    final admin = adminDoc.data()!;
    final creditsToAdd = (invite['credits'] as num?)?.toInt() ?? 500;

    await _db.runTransaction((tx) async {
      tx.update(_db.collection('users').doc(uid), {
        'isAdmin': false,
        'parentAdminId': invite['adminId'],
        'subscriptionPlan': invite['plan'],
        'credits': FieldValue.increment(creditsToAdd),
        'institutionName': admin['institutionName'] ?? '',
      });
      tx.update(_db.collection('invite_codes').doc(code.toUpperCase()), {
        'usedBy': uid,
        'usedAt': FieldValue.serverTimestamp(),
      });
    });

    return {
      'success': true,
      'plan': invite['plan'],
      'credits': creditsToAdd,
      'institutionName': admin['institutionName'] ?? '',
    };
  }

  Future<Map<String, dynamic>> generateInviteCode({String plan = 'starter', int? credits}) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final code = List.generate(6, (_) {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      return chars[Random.secure().nextInt(chars.length)];
    }).join();

    await _db.collection('invite_codes').doc(code).set({
      'code': code,
      'adminId': uid,
      'plan': plan,
      'credits': credits ?? 500,
      'usedBy': null,
      'usedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {'success': true, 'code': code};
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) throw Exception('User not found');
    final user = userDoc.data()!;

    String effectivePlan(String plan, Map<String, dynamic> userData) {
      if (plan == 'unlimited') {
        final expiryStr = userData['subscriptionExpiry'] as String?;
        if (expiryStr != null) {
          final expiry = DateTime.tryParse(expiryStr);
          if (expiry != null && DateTime.now().isAfter(expiry)) return 'basic';
        }
      }
      return plan;
    }

    final planId = effectivePlan(user['subscriptionPlan'] ?? 'basic', user);
    final expiryStr = user['subscriptionExpiry'] as String?;

    if (user['parentAdminId'] != null) {
      final adminDoc = await _db.collection('users').doc(user['parentAdminId'] as String).get();
      final admin = adminDoc.data()!;
      final inviteSnap = await _db.collection('invite_codes')
        .where('usedBy', isEqualTo: uid)
        .limit(1)
        .get();
      final invite = inviteSnap.docs.isEmpty ? null : inviteSnap.docs.first.data();
      final teachersSnap = await _db.collection('users')
        .where('parentAdminId', isEqualTo: user['parentAdminId'])
        .get();

      final adminPlan = effectivePlan(admin['subscriptionPlan'] ?? 'basic', admin);

      return {
        'success': true,
        'subscription': {
          'planId': adminPlan,
          'subscriptionExpiry': admin['subscriptionExpiry'],
          'inviteCode': invite?['code'],
          'institutionName': admin['institutionName'] ?? '',
          'defaultInviteCredits': 500,
          'teachers': teachersSnap.docs.map((d) {
            final t = d.data();
            final allocated = (t['allocatedScans'] as num?)?.toInt() ?? 0;
            final credits = (t['credits'] as num?)?.toInt() ?? 0;
            return {
              'uid': d.id,
              'email': t['email'],
              'name': t['name'],
              'allocatedScans': allocated,
              'usedScans': allocated > 0 ? (allocated - credits).clamp(0, allocated) : 0,
              'isActive': t['isActive'] ?? true,
              'createdAt': 0,
            };
          }).toList(),
        },
      };
    }

      final teachersSnap = await _db.collection('users')
        .where('parentAdminId', isEqualTo: uid)
        .get();
    final inviteSnap = await _db.collection('invite_codes')
      .where('adminId', isEqualTo: uid)
      .where('usedBy', isEqualTo: null)
      .limit(1)
      .get();
    final invite = inviteSnap.docs.isEmpty ? null : inviteSnap.docs.first.data();

    return {
      'success': true,
      'subscription': {
        'planId': planId,
        'subscriptionExpiry': expiryStr,
        'inviteCode': invite?['code'],
        'institutionName': user['institutionName'] ?? '',
        'defaultInviteCredits': 500,
        'teachers': teachersSnap.docs.map((d) {
          final t = d.data();
          final allocated = (t['allocatedScans'] as num?)?.toInt() ?? 0;
          final credits = (t['credits'] as num?)?.toInt() ?? 0;
          return {
            'uid': d.id,
            'email': t['email'],
            'name': t['name'],
            'allocatedScans': allocated,
            'usedScans': allocated > 0 ? (allocated - credits).clamp(0, allocated) : 0,
            'isActive': t['isActive'] ?? true,
            'createdAt': 0,
          };
        }).toList(),
      },
    };
  }

  Future<Map<String, dynamic>> updateProfile({String? name, String? institutionName}) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final update = <String, dynamic>{};
    if (name != null) update['name'] = name;
    if (institutionName != null) {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.data()?['isAdmin'] != true) throw Exception('Only admins can change institution name');
      update['institutionName'] = institutionName;
    }
    if (update.isNotEmpty) await _db.collection('users').doc(uid).update(update);
    return {'success': true};
  }

  Future<Map<String, dynamic>> listCourses() async {
    final snap = await _db.collection('courses').orderBy('code').get();
    return {'success': true, 'courses': snap.docs.map((d) => _docToMap(d)).toList()};
  }

  Future<Map<String, dynamic>> createCourse(String code, String name) async {
    final ref = await _db.collection('courses').add({
      'code': code.toUpperCase(),
      'name': name,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return {'success': true, 'id': ref.id};
  }

  Future<Map<String, dynamic>> listSessions() async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final snap = await _db.collection('sessions')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .get();
    return {'success': true, 'sessions': snap.docs.map((d) => _docToMap(d)).toList()};
  }

  Future<Map<String, dynamic>> createSession({required String name, String subject = 'General', String courseCode = '', int maxMark = 100, String extractionType = 'Exam'}) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final ref = await _db.collection('sessions').add({
      'name': name,
      'subject': subject,
      'courseCode': courseCode,
      'maxMark': maxMark,
      'extractionType': extractionType,
      'userId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return {'success': true, 'id': ref.id};
  }

  Future<Map<String, dynamic>> deleteSession(String sessionId) async {
    await _db.collection('sessions').doc(sessionId).delete();
    return {'success': true};
  }

  Future<Map<String, dynamic>> addCredits(int count) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.data()?['isAdmin'] != true) throw Exception('Only admins can add credits');
    await _db.collection('users').doc(uid).update({'credits': FieldValue.increment(count)});
    return {'success': true, 'creditsAdded': count};
  }

  Future<Map<String, dynamic>> allocateTeamMemberScans(String memberUid, int additionalScans) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.data()?['isAdmin'] != true) throw Exception('Only admins can allocate scans');
    await _db.collection('users').doc(memberUid).update({
      'allocatedScans': FieldValue.increment(additionalScans),
      'credits': FieldValue.increment(additionalScans),
    });
    return {'success': true};
  }

  Future<Map<String, dynamic>> toggleTeamMemberActive(String memberUid, bool isActive) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.data()?['isAdmin'] != true) throw Exception('Only admins can toggle active');
    await _db.collection('users').doc(memberUid).update({'isActive': isActive});
    return {'success': true};
  }

  Future<Map<String, dynamic>> removeTeamMember(String memberUid) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.data()?['isAdmin'] != true) throw Exception('Only admins can remove team members');
    await _db.collection('users').doc(memberUid).update({
      'parentAdminId': FieldValue.delete(),
      'isActive': false,
    });
    return {'success': true};
  }

  Future<Map<String, dynamic>> getUserByEmail(String email) async {
    final snap = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    if (snap.docs.isEmpty) return {'success': false, 'user': null};
    return {'success': true, 'user': _docToMap(snap.docs.first)};
  }
}
