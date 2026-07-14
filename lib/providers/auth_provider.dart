import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

class AppUser {
  final String id;
  final String email;
  final String? name;
  final bool isAdmin;
  final int credits;
  final String? parentAdminId;
  AppUser({required this.id, required this.email, this.name, this.isAdmin = false, this.credits = 0, this.parentAdminId});
}

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _user;
  bool _isLoading = false;
  bool _initialized = false;
  String? _errorMessage;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  int get credits => _user?.credits ?? 0;

  AuthProvider();

  Future<bool> tryAutoLogin() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _initialized = true;
      return false;
    }
    return _loadUser(currentUser.uid);
  }

  Future<bool> _loadUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        _initialized = true;
        return false;
      }
      final data = doc.data()!;
      _user = AppUser(
        id: uid,
        email: data['email'] as String? ?? '',
        name: data['name'] as String?,
        isAdmin: data['isAdmin'] as bool? ?? false,
        credits: (data['credits'] as num?)?.toInt() ?? 0,
        parentAdminId: data['parentAdminId'] as String?,
      );
      _initialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      LoggerService.instance.logError('AuthProvider', 'Auto login failed: $e');
      _initialized = true;
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String name, {bool isAdmin = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.updateDisplayName(name);

      final uid = credential.user!.uid;
      final userData = {
        'email': email,
        'name': _capitalize(name),
        'isAdmin': isAdmin,
        'credits': 3,
        'subscriptionPlan': 'basic',
        'institutionName': '',
        'parentAdminId': null,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _firestore.collection('users').doc(uid).set(userData);

      _user = AppUser(id: uid, email: email, name: _capitalize(name), isAdmin: isAdmin, credits: 3);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userEmail', email);
      await prefs.setString('userName', _capitalize(name));
      await prefs.setBool('isAdmin', isAdmin);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Sign up failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network error: unable to connect';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final uid = credential.user!.uid;
      final loaded = await _loadUser(uid);

      if (loaded) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userEmail', email);
        if (_user?.name != null) await prefs.setString('userName', _user!.name!);
        await prefs.setBool('isAdmin', _user?.isAdmin ?? false);
      }

      _isLoading = false;
      notifyListeners();
      return loaded;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Sign in failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network error: unable to connect';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await GoogleSignIn().signOut();
    await _auth.signOut();
    _user = null;
    await prefs.remove('userEmail');
    await prefs.remove('userName');
    await prefs.remove('isAdmin');
    await prefs.remove('credits');
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _isLoading = false;
        _errorMessage = 'Sign in cancelled';
        notifyListeners();
        return false;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final uid = userCredential.user!.uid;
      final email = userCredential.user!.email ?? '';

      // Check if user doc exists, create if not
      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        final displayName = userCredential.user!.displayName ?? email.split('@').first;
        await docRef.set({
          'email': email,
          'name': _capitalize(displayName),
          'isAdmin': false,
          'credits': 3,
          'subscriptionPlan': 'basic',
          'institutionName': '',
          'parentAdminId': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final loaded = await _loadUser(uid);
      if (loaded) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userEmail', email);
        if (_user?.name != null) await prefs.setString('userName', _user!.name!);
        await prefs.setBool('isAdmin', _user?.isAdmin ?? false);
      }

      _isLoading = false;
      notifyListeners();
      return loaded;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Google sign in failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network error: unable to connect';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        _errorMessage = 'Not logged in';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Password change failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network error: unable to connect';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({String? name, String? institutionName}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ApiService().updateProfile(name: name, institutionName: institutionName);
      if (name != null) {
        await _auth.currentUser?.updateDisplayName(name);
        _user = AppUser(
          id: _user!.id,
          email: _user!.email,
          name: _capitalize(name),
          isAdmin: _user!.isAdmin,
          credits: _user!.credits,
          parentAdminId: _user!.parentAdminId,
        );
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Network error: unable to connect';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshCredits() async {
    try {
      final res = await ApiService().getCreditsBalance();
      if (res['success'] == true && _user != null) {
        final newCredits = (res['credits'] as num).toInt();
        _user = AppUser(
          id: _user!.id,
          email: _user!.email,
          name: _user!.name,
          isAdmin: _user!.isAdmin,
          credits: newCredits,
          parentAdminId: _user!.parentAdminId,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> addCredits(int count) async {
    if (_user == null) return;
    try {
      await ApiService().addCredits(count);
    } catch (_) {}
    await refreshCredits();
  }

  Future<void> deductCredits(int count) async {
    if (_user == null) return;
    try {
      await ApiService().deductCredits(count: count);
    } catch (_) {}
    await refreshCredits();
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
