import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EduColors.offWhite,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer3<AuthProvider, SubscriptionProvider, ThemeProvider>(
        builder: (context, auth, sub, themeProv, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileCard(auth),
            if (auth.isAdmin) ...[
              const SizedBox(height: 20),
              _buildSubscriptionCard(context, sub),
              const SizedBox(height: 12),
              _buildPurchaseButton(context),
            ],
            const SizedBox(height: 20),
            _buildSection('Appearance', [
              _buildThemeTile(context, themeProv),
            ]),
            const SizedBox(height: 20),
            _buildSection('OCR Engine', [
              _buildOcrEngineTile(context),
            ]),
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
                onTap: () => _showComingSoon(context),
              ),
              _buildSettingTile(
                Icons.lock_outlined,
                'Change Password',
                onTap: () => _showComingSoon(context),
              ),
              _buildSettingTile(
                Icons.privacy_tip_outlined,
                'Privacy Policy',
                onTap: () => _showComingSoon(context),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Support', [
              _buildSettingTile(
                Icons.help_outline,
                'Help & Support',
                onTap: () => _showComingSoon(context),
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

  Widget _buildThemeTile(BuildContext context, ThemeProvider themeProv) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.dark_mode_outlined, color: EduColors.textMedium),
          title: Text('Theme', style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textDark)),
          subtitle: Text(
            themeProv.isLight ? 'Light' : (themeProv.isDark ? 'Dark' : 'System'),
            style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textLight),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              _themeOption(
                icon: Icons.light_mode,
                label: 'Light',
                selected: themeProv.isLight,
                onTap: () => themeProv.setMode(ThemeMode.light),
              ),
              const SizedBox(width: 8),
              _themeOption(
                icon: Icons.dark_mode,
                label: 'Dark',
                selected: themeProv.isDark,
                onTap: () => themeProv.setMode(ThemeMode.dark),
              ),
              const SizedBox(width: 8),
              _themeOption(
                icon: Icons.settings_brightness,
                label: 'System',
                selected: themeProv.isSystem,
                onTap: () => themeProv.setMode(ThemeMode.system),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _themeOption({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? EduColors.royalBlueLight : EduColors.offWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? EduColors.royalBlue : EduColors.cardBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: selected ? EduColors.royalBlue : EduColors.textMedium),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? EduColors.royalBlue : EduColors.textMedium,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOcrEngineTile(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.visibility, color: EduColors.textMedium),
          title: Text('OCR Engine', style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textDark)),
          subtitle: Text('Gemini AI', style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textLight)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              _ocrOption(
                icon: Icons.auto_awesome,
                label: 'Gemini AI',
                subtitle: 'Server-side',
                selected: true,
              ),
              const SizedBox(width: 8),
              _ocrOption(
                icon: Icons.phone_android,
                label: 'ML Kit',
                subtitle: 'On-device',
                selected: false,
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ocrOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? EduColors.royalBlueLight : EduColors.offWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? EduColors.royalBlue : EduColors.cardBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: selected ? EduColors.royalBlue : EduColors.textMedium),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? EduColors.royalBlue : EduColors.textDark,
              )),
              Text(subtitle, style: GoogleFonts.poppins(
                fontSize: 10, color: EduColors.textLight,
              )),
            ],
          ),
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

  Widget _buildPurchaseButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => GoRouter.of(context).push('/purchase'),
        icon: const Icon(Icons.workspace_premium),
        label: Text(
          'Upgrade Plan – Unlock More Features',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: EduColors.royalBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coming soon', style: GoogleFonts.poppins()),
        backgroundColor: EduColors.royalBlue,
      ),
    );
  }
}
