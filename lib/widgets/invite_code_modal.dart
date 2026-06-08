import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../utils/theme.dart';
import 'dialog_header.dart';

class InviteCodeResult {
  final bool joinedTeam;
  final String? institutionName;
  InviteCodeResult({required this.joinedTeam, this.institutionName});
}

class InviteCodeModal extends StatefulWidget {
  const InviteCodeModal({super.key});

  @override
  State<InviteCodeModal> createState() => _InviteCodeModalState();
}

class _InviteCodeModalState extends State<InviteCodeModal> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) {
      setState(() => _error = 'Enter both the code and your name');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    final auth = context.read<AuthProvider>();
    final sub = context.read<SubscriptionProvider>();
    final isValid = sub.validateInviteCode(code);
    if (!isValid) {
      setState(() { _isLoading = false; _error = 'Invalid or expired code'; });
      return;
    }
    final success = await auth.signInWithInviteCode(code, name);
    if (success) {
      sub.consumeInviteCode(code, name);
      if (mounted) {
        Navigator.pop(context, InviteCodeResult(
          joinedTeam: true,
          institutionName: sub.institutionName,
        ));
      }
    } else {
      setState(() { _isLoading = false; _error = auth.errorMessage ?? 'Failed to join'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DialogHeader(
              icon: Icons.vpn_key,
              title: 'Join a Team',
              subtitle: 'Enter an invitation code from your school or institution',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Invitation Code',
                prefixIcon: Icon(Icons.vpn_key, color: EduColors.royalBlue),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Full Name',
                prefixIcon: Icon(Icons.person, color: EduColors.royalBlue),
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: EduColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: GoogleFonts.poppins(fontSize: 12, color: EduColors.error)),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EduColors.royalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Join Team', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, InviteCodeResult(joinedTeam: false)),
              child: Text('Skip — I\'m an admin', style: GoogleFonts.poppins(color: EduColors.textMedium)),
            ),
          ],
        ),
      ),
    );
  }
}
