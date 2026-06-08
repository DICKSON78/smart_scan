import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

class AppUser {
  final String email;
  final String? name;
  final bool isAdmin;
  final int credits;
  AppUser({required this.email, this.name, this.isAdmin = true, this.credits = 0});
}

class AuthProvider with ChangeNotifier {
  AppUser? _user;
  bool _isLoading = false;
  bool _initialized = false;
  String? _errorMessage;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.isAdmin ?? true;
  int get credits => _user?.credits ?? 0;

  AuthProvider() {
    _initialized = true;
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null) return false;

    final name = prefs.getString('userName');
    final isAdmin = prefs.getBool('isAdmin') ?? true;
    final credits = prefs.getInt('credits') ?? 0;
    _user = AppUser(email: email, name: name, isAdmin: isAdmin, credits: credits);
    _initialized = true;
    notifyListeners();
    return true;
  }

  Future<bool> signUp(String email, String password, String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      if (ApiConfig.useApi) {
        try {
          final result = await ApiService().signup(email, password, name);
          final user = result['user'] as Map<String, dynamic>;
          await prefs.setString('userEmail', user['email'] as String);
          await prefs.setString('userName', user['name'] as String);
          await prefs.setBool('isAdmin', (user['isAdmin'] as bool?) ?? true);
          await prefs.setInt('credits', (user['credits'] as num?)?.toInt() ?? 0);
          await prefs.setBool('hasSeenOnboarding', true);
          _user = AppUser(
            email: user['email'] as String,
            name: user['name'] as String?,
            isAdmin: (user['isAdmin'] as bool?) ?? true,
            credits: (user['credits'] as num?)?.toInt() ?? 0,
          );
          _isLoading = false;
          notifyListeners();
          return true;
        } on ApiException catch (e) {
          _errorMessage = e.message;
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      await prefs.setString('userEmail', email);
      await prefs.setString('userName', name);
      await prefs.setBool('isAdmin', true);
      await prefs.setBool('hasSeenOnboarding', true);
      await prefs.setInt('credits', 50);
      _user = AppUser(email: email, name: name, isAdmin: true, credits: 50);
      _isLoading = false;
      notifyListeners();
      LoggerService.instance.logRegistration(name, email);
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      if (ApiConfig.useApi) {
        try {
          final result = await ApiService().signin(email, password);
          final user = result['user'] as Map<String, dynamic>;
          await prefs.setString('userEmail', user['email'] as String);
          await prefs.setString('userName', user['name'] as String);
          await prefs.setBool('isAdmin', (user['isAdmin'] as bool?) ?? true);
          await prefs.setInt('credits', (user['credits'] as num?)?.toInt() ?? 0);
          await prefs.setBool('hasSeenOnboarding', true);
          _user = AppUser(
            email: user['email'] as String,
            name: user['name'] as String?,
            isAdmin: (user['isAdmin'] as bool?) ?? true,
            credits: (user['credits'] as num?)?.toInt() ?? 0,
          );
          _isLoading = false;
          notifyListeners();
          return true;
        } on ApiException catch (e) {
          _errorMessage = e.message;
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      final storedName = prefs.getString('userName');
      final name = storedName ?? email.split('@').first;
      final storedCredits = prefs.getInt('credits') ?? 50;
      final storedIsAdmin = prefs.getBool('isAdmin') ?? true;
      await prefs.setString('userEmail', email);
      await prefs.setBool('hasSeenOnboarding', true);
      _user = AppUser(email: email, name: name, isAdmin: storedIsAdmin, credits: storedCredits);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithInviteCode(String code, String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      if (ApiConfig.useApi) {
        try {
          final result = await ApiService().inviteLogin(code, name);
          final user = result['user'] as Map<String, dynamic>;
          await prefs.setString('userEmail', user['email'] as String);
          await prefs.setString('userName', user['name'] as String);
          await prefs.setBool('isAdmin', false);
          await prefs.setInt('credits', (user['credits'] as num?)?.toInt() ?? 0);
          await prefs.setBool('hasSeenOnboarding', true);
          _user = AppUser(
            email: user['email'] as String,
            name: user['name'] as String?,
            isAdmin: false,
            credits: (user['credits'] as num?)?.toInt() ?? 0,
          );
          _isLoading = false;
          notifyListeners();
          return true;
        } on ApiException catch (e) {
          _errorMessage = e.message;
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      final placeholderEmail = 'invited_${DateTime.now().millisecondsSinceEpoch}@temp.com';
      final inviteCredits = prefs.getInt('invite_code_credits_$code') ?? 500;
      await prefs.setString('userEmail', placeholderEmail);
      await prefs.setString('userName', name);
      await prefs.setBool('isAdmin', false);
      await prefs.setBool('hasSeenOnboarding', true);
      await prefs.setInt('credits', inviteCredits);
      _user = AppUser(email: placeholderEmail, name: name, isAdmin: false, credits: inviteCredits);
      _isLoading = false;
      notifyListeners();
      LoggerService.instance.logInviteRedeemed(code, name);
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    if (ApiConfig.useApi && ApiConfig.authToken != null) {
      try {
        await ApiService().logout();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userEmail');
    await prefs.remove('userName');
    await prefs.remove('isAdmin');
    ApiConfig.authToken = null;
    _user = null;
    notifyListeners();
  }

  Future<void> addCredits(int count) async {
    if (_user == null) return;
    final newCredits = _user!.credits + count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('credits', newCredits);
    _user = AppUser(
      email: _user!.email,
      name: _user!.name,
      isAdmin: _user!.isAdmin,
      credits: newCredits,
    );
    notifyListeners();
  }

  Future<void> deductCredits(int count) async {
    if (_user == null) return;
    final newCredits = (_user!.credits - count).clamp(0, 999999999);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('credits', newCredits);
    _user = AppUser(
      email: _user!.email,
      name: _user!.name,
      isAdmin: _user!.isAdmin,
      credits: newCredits,
    );
    notifyListeners();
  }

  Future<void> refreshCredits() async {
    if (!ApiConfig.useApi) return;
    try {
      final result = await ApiService().getCreditsBalance();
      final newCredits = result['credits'] as int;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('credits', newCredits);
      if (_user != null) {
        _user = AppUser(
          email: _user!.email,
          name: _user!.name,
          isAdmin: _user!.isAdmin,
          credits: newCredits,
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
