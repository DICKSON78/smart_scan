import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ClickPesaPaymentResult {
  final bool success;
  final String? orderReference;
  final String? message;
  final String? error;

  ClickPesaPaymentResult({
    required this.success,
    this.orderReference,
    this.message,
    this.error,
  });
}

class ClickPesaService {
  final String _baseUrl = 'https://api.clickpesa.com/third-parties';
  final http.Client _client = http.Client();

  // ── Get bearer token with retry ───────────────────────────────────────────
  Future<String> _getToken({int retries = 2}) async {
    for (int i = 0; i <= retries; i++) {
      try {
        final res = await _client.post(
          Uri.parse('$_baseUrl/generate-token'),
          headers: {
            'Content-Type': 'application/json',
            'client-id': ApiConfig.clickPesaClientId,
            'api-key': ApiConfig.clickPesaApiKey,
          },
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) {
          final err = jsonDecode(res.body);
          throw Exception(err['message'] ?? err['error'] ?? 'Failed to get token');
        }
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['token'] as String).replaceFirst('Bearer ', '');
      } on SocketException {
        if (i == retries) rethrow;
      } on TimeoutException {
        if (i == retries) rethrow;
      }
      await Future.delayed(Duration(seconds: 1 << i));
    }
    throw Exception('Unable to connect to payment service');
  }

  // ── Generate random alphanumeric order reference ──────────────────────────
  String _generateOrderRef() {
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    final buf = StringBuffer('EME');
    for (int i = 0; i < 13; i++) {
      buf.write(chars[rng.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  // ── Save payment intent to Firestore ──────────────────────────────────────
  Future<void> _savePaymentIntent(String orderRef, String uid, int scans, String planId) async {
    await FirebaseFirestore.instance.collection('payments').doc(orderRef).set({
      'uid': uid,
      'scans': scans,
      'planId': planId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Initiate USSD Push ────────────────────────────────────────────────────
  Future<ClickPesaPaymentResult> initiateUSSDPush({
    required String uid,
    required String planId,
    required int amount,
    required int scans,
    required String phone,
  }) async {
    try {
      String p = phone.replaceAll(RegExp(r'\D'), '');
      if (p.length == 9 && p.startsWith('7')) {
        p = '255$p';
      } else if (p.length == 10 && p.startsWith('0')) {
        p = '255${p.substring(1)}';
      } else if (p.length != 12 || !p.startsWith('255')) {
        return ClickPesaPaymentResult(success: false, error: 'Invalid phone');
      }

      if (amount < 908) {
        return ClickPesaPaymentResult(success: false, error: 'Minimum amount is Tshs 908');
      }

      final orderRef = _generateOrderRef();
      final token = await _getToken();

      final res = await _client.post(
        Uri.parse('$_baseUrl/payments/initiate-ussd-push-request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount.toString(),
          'currency': 'TZS',
          'orderReference': orderRef,
          'phoneNumber': p,
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        final err = jsonDecode(res.body);
        return ClickPesaPaymentResult(
          success: false,
          error: err['message'] ?? err['error'] ?? 'Payment initiation failed',
        );
      }

      // Save intent so we can match when polling succeeds
      await _savePaymentIntent(orderRef, uid, scans, planId);

      return ClickPesaPaymentResult(
        success: true,
        orderReference: orderRef,
        message: 'Payment initiated. Check your phone for the USSD prompt.',
      );
    } on SocketException {
      return ClickPesaPaymentResult(success: false, error: 'Network error');
    } on TimeoutException {
      return ClickPesaPaymentResult(success: false, error: 'Connection timed out');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('token') || msg.contains('auth')) {
        return ClickPesaPaymentResult(success: false, error: 'Authentication failed');
      }
      return ClickPesaPaymentResult(success: false, error: 'Network error');
    }
  }

  // ── Query ClickPesa for payment status ────────────────────────────────────
  Future<String> queryClickPesaStatus(String orderRef) async {
    try {
      final token = await _getToken();
      final res = await _client.get(
        Uri.parse('$_baseUrl/payments/$orderRef'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 404) return 'PENDING';
      if (res.statusCode != 200) return 'UNKNOWN';

      final list = jsonDecode(res.body) as List;
      if (list.isEmpty) return 'PENDING';
      return (list[0]['status'] as String? ?? 'PENDING').toUpperCase();
    } catch (_) {
      return 'UNKNOWN';
    }
  }

  // ── Credit user in Firestore after successful payment ─────────────────────
  Future<void> _creditUser(String orderRef) async {
    final docRef = FirebaseFirestore.instance.collection('payments').doc(orderRef);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    if (data['status'] == 'completed') return; // already credited

    final uid = data['uid'] as String?;
    final scans = data['scans'] as int? ?? 0;
    final planId = data['planId'] as String? ?? 'basic';

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != uid) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final userDoc = await tx.get(userRef);
      final currentCredits = (userDoc.data()?['credits'] as num?)?.toInt() ?? 0;
      tx.update(userRef, {
        'credits': currentCredits + scans,
        'subscriptionPlan': planId,
        'lastPayment': {
          'orderReference': orderRef,
          'scans': scans,
          'planId': planId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    });

    await docRef.update({'status': 'completed'});
  }

  // ── Poll ClickPesa until completed or failed ──────────────────────────────
  Future<bool> pollForPayment(String orderRef) async {
    final maxAttempts = ApiConfig.paymentPollMaxAttempts;
    final interval = Duration(seconds: ApiConfig.paymentPollIntervalSec);

    for (int i = 0; i < maxAttempts; i++) {
      final status = await queryClickPesaStatus(orderRef);

      if (status == 'SUCCESS' || status == 'SETTLED') {
        await _creditUser(orderRef);
        return true;
      }

      if (status == 'FAILED') return false;

      await Future.delayed(interval);
    }

    // Mark as timed out
    try {
      await FirebaseFirestore.instance.collection('payments').doc(orderRef).update({'status': 'timed_out'});
    } catch (_) {}
    return false;
  }

  void dispose() {
    _client.close();
  }
}
