// ignore_for_file: use_null_aware_elements

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  final _client = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (ApiConfig.authToken != null)
          'Authorization': 'Bearer ${ApiConfig.authToken}',
      };

  String _url(String path) => '${ApiConfig.baseUrl}$path';

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(_url(path)).replace(queryParameters: queryParams);
    http.Response response;

    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: _headers);
        break;
      case 'POST':
        response = await _client.post(uri, headers: _headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'DELETE':
        response = await _client.delete(uri, headers: _headers);
        break;
      default:
        throw ApiException('Unsupported method: $method', 400);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw ApiException(
        data['error']?.toString() ?? 'Request failed',
        response.statusCode,
      );
    }

    return data;
  }

  // ---- Auth ----
  Future<Map<String, dynamic>> signup(String email, String password, String name) async {
    final data = await _request('POST', ApiConfig.signup, body: {
      'email': email,
      'password': password,
      'name': name,
    });
    ApiConfig.authToken = data['token'] as String?;
    return data;
  }

  Future<Map<String, dynamic>> signin(String email, String password) async {
    final data = await _request('POST', ApiConfig.signin, body: {
      'email': email,
      'password': password,
    });
    ApiConfig.authToken = data['token'] as String?;
    return data;
  }

  Future<Map<String, dynamic>> inviteLogin(String code, String name) async {
    final data = await _request('POST', ApiConfig.inviteLogin, body: {
      'code': code,
      'name': name,
    });
    ApiConfig.authToken = data['token'] as String?;
    return data;
  }

  Future<Map<String, dynamic>> getProfile() async {
    return _request('GET', ApiConfig.profile);
  }

  // ---- Courses ----
  Future<Map<String, dynamic>> listCourses() async {
    return _request('GET', ApiConfig.courses);
  }

  Future<Map<String, dynamic>> createCourse(String code, String name) async {
    return _request('POST', ApiConfig.courses, body: {
      'code': code,
      'name': name,
    });
  }

  Future<Map<String, dynamic>> deleteCourse(int id) async {
    return _request('DELETE', '/courses/$id');
  }

  // ---- Credits (deduct without storing marks) ----
  Future<Map<String, dynamic>> deductCredits({int count = 1}) async {
    return _request('POST', ApiConfig.creditsDeduct, body: {
      'count': count,
    });
  }

  // ---- Team ----
  Future<Map<String, dynamic>> teamMembers() async {
    return _request('GET', ApiConfig.teamMembers);
  }

  Future<Map<String, dynamic>> teamInvite() async {
    return _request('POST', ApiConfig.teamInvite);
  }

  Future<Map<String, dynamic>> removeTeamMember(int teacherId) async {
    return _request('DELETE', '/team/members/$teacherId');
  }

  Future<Map<String, dynamic>> teamAllocate(int teacherId, int credits) async {
    return _request('POST', ApiConfig.teamAllocate, body: {
      'teacherId': teacherId,
      'credits': credits,
    });
  }

  Future<Map<String, dynamic>> teamUsage() async {
    return _request('GET', ApiConfig.teamUsage);
  }

  // ---- Credits ----
  Future<Map<String, dynamic>> getCreditsBalance() async {
    return _request('GET', ApiConfig.creditsBalance);
  }

  Future<Map<String, dynamic>> topupCredits({int? amount, String? package}) async {
    return _request('POST', ApiConfig.creditsTopup, body: {
      if (amount != null) 'amount': amount,
      if (package != null) 'package': package,
    });
  }

  Future<Map<String, dynamic>> getMyUsage() async {
    return _request('GET', ApiConfig.creditsMyUsage);
  }

  // ---- Subscription ----
  Future<Map<String, dynamic>> listPlans() async {
    return _request('GET', ApiConfig.subscriptionPlans);
  }

  Future<Map<String, dynamic>> subscriptionStatus() async {
    return _request('GET', ApiConfig.subscriptionStatus);
  }

  Future<Map<String, dynamic>> purchasePlan(String planId) async {
    return _request('POST', ApiConfig.subscriptionPurchase, body: {
      'planId': planId,
    });
  }

  // ---- Logout ----
  Future<Map<String, dynamic>> logout() async {
    return _request('POST', ApiConfig.logout);
  }

  // ---- Setup ----
  Future<Map<String, dynamic>> runSetup() async {
    return _request('GET', ApiConfig.setup);
  }
}
