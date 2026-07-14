import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/error_dialog.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  int _tabIndex = 0;

  final _personalFormKey = GlobalKey<FormState>();
  final _personalNameCtrl = TextEditingController();
  final _personalEmailCtrl = TextEditingController();
  final _personalPassCtrl = TextEditingController();
  final _personalConfirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  final _instFormKey = GlobalKey<FormState>();
  final _instNameCtrl = TextEditingController();
  final _instEmailCtrl = TextEditingController();
  final _instPassCtrl = TextEditingController();
  final _instConfirmCtrl = TextEditingController();
  final _instInstNameCtrl = TextEditingController();
  final _instPhoneCtrl = TextEditingController();
  final _instAddressCtrl = TextEditingController();
  bool _instObscurePass = true;
  bool _instObscureConfirm = true;

  @override
  void dispose() {
    _personalNameCtrl.dispose();
    _personalEmailCtrl.dispose();
    _personalPassCtrl.dispose();
    _personalConfirmCtrl.dispose();
    _instNameCtrl.dispose();
    _instEmailCtrl.dispose();
    _instPassCtrl.dispose();
    _instConfirmCtrl.dispose();
    _instInstNameCtrl.dispose();
    _instPhoneCtrl.dispose();
    _instAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUpPersonal() async {
    if (!_personalFormKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      _personalEmailCtrl.text.trim(),
      _personalPassCtrl.text,
      _personalNameCtrl.text.trim(),
      isAdmin: false,
    );

    if (!mounted) return;

    if (success) {
      GoRouter.of(context).go('/home');
    } else if (mounted) {
      showErrorDialog(context, ErrorDialogConfig(
        title: 'Sign Up Failed',
        message: _friendlySignupError(auth.errorMessage),
        type: ErrorDialogType.error,
      ));
    }
  }

  Future<void> _signUpInstitute() async {
    if (!_instFormKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final sub = context.read<SubscriptionProvider>();

    final success = await auth.signUp(
      _instEmailCtrl.text.trim(),
      _instPassCtrl.text,
      _instNameCtrl.text.trim(),
      isAdmin: false,
    );

    if (!mounted) return;

    if (success) {
      final instName = _instInstNameCtrl.text.trim();
      if (instName.isNotEmpty) {
        sub.setInstitutionName(instName);
      }
      GoRouter.of(context).go('/home');
    } else if (mounted) {
      showErrorDialog(context, ErrorDialogConfig(
        title: 'Sign Up Failed',
        message: _friendlySignupError(auth.errorMessage),
        type: ErrorDialogType.error,
      ));
    }
  }

  String _friendlySignupError(String? error) {
    if (error == null) return 'Something went wrong. Please try again.';
    final e = error.toLowerCase();
    if (e.contains('email-already-in-use')) return 'This email is already registered. Please sign in instead.';
    if (e.contains('weak-password')) return 'Password is too weak. Please use at least 8 characters with a mix of letters and numbers.';
    if (e.contains('invalid-email')) return 'Please enter a valid email address.';
    if (e.contains('operation-not-allowed')) return 'Email/Password sign up is not available. Please try another method.';
    if (e.contains('network') || e.contains('socket') || e.contains('timeout')) {
      return 'Unable to connect. Please check your internet connection.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (Icons.person, 'Personal'),
      (Icons.business, 'Institute'),
    ];

    return Scaffold(
      backgroundColor: EduColors.offWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: EduColors.cardBorder, width: 2),
                  ),
                  padding: const EdgeInsets.all(5),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.jpeg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Create Account',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: EduColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose your account type',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: EduColors.textMedium,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: EduColors.white,
                  border: Border(bottom: BorderSide(color: EduColors.cardBorder.withValues(alpha: 0.5))),
                ),
                child: Row(
                  children: List.generate(tabs.length, (i) {
                    final icon = tabs[i].$1;
                    final label = tabs[i].$2;
                    final isActive = _tabIndex == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tabIndex = i),
                        child: Container(
                          padding: const EdgeInsets.only(top: 10, bottom: 6),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isActive ? EduColors.royalBlue : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 22, color: isActive ? EduColors.royalBlue : EduColors.textMedium),
                              const SizedBox(height: 3),
                              Text(
                                label,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isActive ? EduColors.royalBlue : EduColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _tabIndex == 0 ? _buildPersonalForm() : _buildInstituteForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalForm() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => Form(
        key: _personalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'For individual lecturers & teachers',
              style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _personalNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outlined, color: EduColors.royalBlue),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _personalEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined, color: EduColors.royalBlue),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your email';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _personalPassCtrl,
              obscureText: _obscurePass,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outlined, color: EduColors.royalBlue),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _personalConfirmCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outlined, color: EduColors.royalBlue),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) => (v != _personalPassCtrl.text) ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : _signUpPersonal,
                child: auth.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Already have an account? ', style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium)),
                GestureDetector(
                  onTap: () => context.go('/sign-in'),
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: EduColors.royalBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInstituteForm() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => Form(
        key: _instFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'For schools, colleges & organizations',
              style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _instNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outlined, color: EduColors.royalBlue),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _instEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined, color: EduColors.royalBlue),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your email';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _instPassCtrl,
              obscureText: _instObscurePass,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outlined, color: EduColors.royalBlue),
                suffixIcon: IconButton(
                  icon: Icon(_instObscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _instObscurePass = !_instObscurePass),
                ),
              ),
              validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _instConfirmCtrl,
              obscureText: _instObscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outlined, color: EduColors.royalBlue),
                suffixIcon: IconButton(
                  icon: Icon(_instObscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _instObscureConfirm = !_instObscureConfirm),
                ),
              ),
              validator: (v) => (v != _instPassCtrl.text) ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _instInstNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Institution Name',
                prefixIcon: Icon(Icons.business_outlined, color: EduColors.royalBlue),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _instPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined, color: EduColors.royalBlue),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _instAddressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on_outlined, color: EduColors.royalBlue),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : _signUpInstitute,
                child: auth.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Register Institute', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Already have an account? ', style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium)),
                GestureDetector(
                  onTap: () => context.go('/sign-in'),
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: EduColors.royalBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
