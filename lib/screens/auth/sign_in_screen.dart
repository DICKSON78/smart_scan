import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/invite_code_modal.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (success && mounted) {
        final sub = context.read<SubscriptionProvider>();
        if (sub.currentPlanId == 'basic') {
          final result = await showDialog<InviteCodeResult>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const InviteCodeModal(),
          );
          if (result?.joinedTeam == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result!.institutionName != null
                      ? 'Joined ${result.institutionName} team'
                      : 'Team joined successfully',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: EduColors.success,
              ),
            );
          }
        }
        if (mounted) GoRouter.of(context).go('/home');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Sign in failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    const Icon(Icons.document_scanner, size: 80, color: EduColors.royalBlue),
                    const SizedBox(height: 24),
                    Text('SmartScan Marks', style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold, color: EduColors.textDark,
                    ), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Sign in to your account', style: GoogleFonts.poppins(
                      fontSize: 14, color: EduColors.textMedium,
                    ), textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email, color: EduColors.royalBlue),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your email';
                        if (!value.contains('@')) return 'Please enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock, color: EduColors.royalBlue),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your password';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    authProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => GoRouter.of(context).push('/sign-up'),
                      child: const Text('Don\'t have an account? Sign Up'),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
