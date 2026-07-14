import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/error_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EduColors.offWhite,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer2<AuthProvider, SubscriptionProvider>(
        builder: (context, auth, sub, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileCard(auth),
            if (auth.isAdmin) ...[
              const SizedBox(height: 20),
              _buildSubscriptionCard(context, sub),
            ],
            const SizedBox(height: 20),
            _buildSection('General', [
              _buildSettingTile(
                Icons.notifications_outlined,
                'Notifications',
                trailing: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeThumbColor: EduColors.royalBlue,
                ),
              ),
              _buildSettingTile(
                Icons.language_outlined,
                'Language',
                subtitle: 'English',
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Account', [
              _buildSettingTile(
                Icons.edit_outlined,
                'Edit Profile',
                onTap: () => _showEditProfile(context),
              ),
              _buildSettingTile(
                Icons.lock_outlined,
                'Change Password',
                onTap: () => _showChangePassword(context),
              ),
              _buildSettingTile(
                Icons.privacy_tip_outlined,
                'Privacy Policy',
                onTap: () => _showPrivacyPolicy(context),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Support', [
              _buildSettingTile(
                Icons.help_outline,
                'Help & Support',
                onTap: () => _showHelpSupport(context),
              ),
              _buildSettingTile(
                Icons.info_outline,
                'About',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'SmartScan Marks',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2024 SmartScan Marks',
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await auth.signOut();
                  if (context.mounted) GoRouter.of(context).push('/sign-in');
                },
                icon: const Icon(Icons.logout),
                label: Text('Sign Out', style: GoogleFonts.poppins()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EduColors.error,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(AuthProvider auth) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: EduColors.royalBlueLight,
              child: Icon(Icons.person, size: 32, color: EduColors.royalBlue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.user?.name ?? 'Teacher',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: EduColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.isAdmin ? 'Admin' : 'Teacher',
                    style: GoogleFonts.poppins(fontSize: 13, color: EduColors.royalBlue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, SubscriptionProvider sub) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => GoRouter.of(context).push('/purchase'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: EduColors.royalBlueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.workspace_premium, color: EduColors.royalBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${sub.currentPlan?.name ?? 'Basic'} Plan',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: EduColors.textDark,
                      ),
                    ),
                    Text(
                      '${sub.currentPlan?.teacherCount ?? 1} teacher(s) · ${sub.teacherCount} invited',
                      style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textMedium),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: EduColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: EduColors.textMedium,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingTile(
    IconData icon,
    String title, {
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: EduColors.textMedium),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textDark)),
      subtitle: subtitle != null
          ? Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textLight))
          : null,
      trailing: trailing ?? Icon(Icons.chevron_right, color: EduColors.textLight),
      onTap: onTap,
    );
  }

  void _showEditProfile(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final nameCtrl = TextEditingController(text: auth.user?.name ?? '');
    final instCtrl = TextEditingController(text: (auth.user?.email != null && auth.isAdmin) ? '' : '');
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_outlined, color: EduColors.royalBlue),
                    const SizedBox(width: 8),
                    Text('Edit Profile', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: EduColors.textDark)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person, color: EduColors.royalBlue),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (auth.isAdmin) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: instCtrl,
                    decoration: InputDecoration(
                      labelText: 'Institution Name',
                      prefixIcon: Icon(Icons.business, color: EduColors.royalBlue),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          setDialogState(() => loading = true);
                          final success = await auth.updateProfile(
                            name: nameCtrl.text.trim(),
                            institutionName: auth.isAdmin && instCtrl.text.trim().isNotEmpty ? instCtrl.text.trim() : null,
                          );
                          if (success && ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Profile updated', style: GoogleFonts.poppins()), backgroundColor: EduColors.success),
                            );
                          } else if (ctx.mounted) {
                            setDialogState(() => loading = false);
                            showErrorDialog(context, ErrorDialogConfig(
                              title: 'Update Failed',
                              message: 'Unable to update your profile. Please try again.',
                              type: ErrorDialogType.error,
                            ));
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EduColors.royalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Save', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outlined, color: EduColors.royalBlue),
                    const SizedBox(width: 8),
                    Text('Change Password', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: EduColors.textDark)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock, color: EduColors.royalBlue),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline, color: EduColors.royalBlue),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_outline, color: EduColors.royalBlue),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (newCtrl.text != confirmCtrl.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Passwords do not match', style: GoogleFonts.poppins()), backgroundColor: EduColors.error),
                            );
                            return;
                          }
                          if (newCtrl.text.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('New password must be at least 6 characters', style: GoogleFonts.poppins()), backgroundColor: EduColors.error),
                            );
                            return;
                          }
                          setDialogState(() => loading = true);
                          final success = await auth.changePassword(currentCtrl.text, newCtrl.text);
                          if (success && ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Password changed successfully', style: GoogleFonts.poppins()), backgroundColor: EduColors.success),
                            );
                          } else if (ctx.mounted) {
                            setDialogState(() => loading = false);
                            showErrorDialog(context, ErrorDialogConfig(
                              title: 'Password Change Failed',
                              message: 'Could not change your password. Please check your current password and try again.',
                              type: ErrorDialogType.error,
                            ));
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EduColors.royalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Change Password', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.privacy_tip_outlined, color: EduColors.royalBlue),
                  const SizedBox(width: 8),
                  Text('Privacy Policy', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: EduColors.textDark)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'SmartScan Marks takes your privacy seriously. We collect only the data necessary to provide our exam mark extraction service.\n\n'
                '• Your account information (name, email) is used for authentication and team management.\n'
                '• Exam marks and student data remain on your device and are never uploaded.\n'
                '• We do not sell, share, or distribute your personal data to third parties.\n'
                '• You can request deletion of your account and associated data at any time.\n\n'
                'For questions, contact support@smartscanmarks.app',
                style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textDark, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EduColors.royalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline, color: EduColors.royalBlue),
                  const SizedBox(width: 8),
                  Text('Help & Support', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: EduColors.textDark)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Need help using SmartScan Marks?\n\n'
                '📧 Email: support@smartscanmarks.app\n'
                '📞 Phone: +255 789 123 456\n'
                '🕐 Response time: Within 24 hours\n\n'
                'For issues with exam mark extraction, credits, or team management, our support team is ready to assist you.',
                style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textDark, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EduColors.royalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
