import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/teacher_allocation.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/course_provider.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../../widgets/error_dialog.dart';

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  State<TeacherManagementScreen> createState() => _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  List<Map<String, dynamic>> _apiTeachers = [];
  bool _loadingTeachers = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _loadingTeachers = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EduColors.offWhite,
      appBar: AppBar(title: const Text('My Team')),
      body: Consumer2<SubscriptionProvider, CourseProvider>(
        builder: (context, sp, cp, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPlanStatusCard(sp),
              const SizedBox(height: 20),
              _buildUpgradeSection(sp),
              if (sp.currentPlanId != 'basic') ...[
                const SizedBox(height: 20),
                _buildInstitutionSection(sp),
                const SizedBox(height: 20),
                _buildInviteCodeSection(context, sp),
              ],
              const SizedBox(height: 20),
              _buildTeachersCard(sp),
              const SizedBox(height: 20),
              _buildCoursesSection(context, cp, sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanStatusCard(SubscriptionProvider sp) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: EduColors.royalBlueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.group, color: EduColors.royalBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sp.institutionName ?? '${sp.currentPlan?.name ?? 'Basic'} Plan',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: EduColors.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sp.activeTeacherCount + 1} of ${sp.maxTeachers} teachers active',
                    style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sp.hasLowScanTeachers ? EduColors.error.withValues(alpha: 0.1) : EduColors.royalBlueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${sp.maxTeachers - sp.teacherCount - 1} slots left',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500,
                    color: sp.hasLowScanTeachers ? EduColors.error : EduColors.royalBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionSection(SubscriptionProvider sp) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: EduColors.royalBlue, size: 20),
                const SizedBox(width: 8),
                Text('Institution', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: EduColors.textDark)),
              ],
            ),
            const SizedBox(height: 12),
            if (sp.institutionName != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(sp.institutionName!, style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textDark)),
                  ),
                  TextButton(
                    onPressed: () => _showEditInstitutionDialog(context, sp),
                    child: Text('Edit', style: GoogleFonts.poppins()),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showEditInstitutionDialog(context, sp),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('Set Institution Name', style: GoogleFonts.poppins()),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Teachers joining via code will see this as their institution',
                style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textLight),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditInstitutionDialog(BuildContext context, SubscriptionProvider sp) {
    final ctrl = TextEditingController(text: sp.institutionName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Institution Name', style: GoogleFonts.poppins()),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: 'School / Institution name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              sp.setInstitutionName(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: Text('Save', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCodeSection(BuildContext context, SubscriptionProvider sp) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.share, color: EduColors.royalBlue, size: 20),
                const SizedBox(width: 8),
                Text('Invite Teachers', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: EduColors.textDark)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sp.institutionName != null
                  ? 'Share this code with teachers to join ${sp.institutionName}'
                  : 'Share this code with other teachers to join your team',
              style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium),
            ),
            const SizedBox(height: 16),
            if (sp.inviteCode != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EduColors.royalBlueLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EduColors.royalBlue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      sp.inviteCode!,
                      style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold,
                          color: EduColors.royalBlue, letterSpacing: 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: sp.inviteCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied!', style: GoogleFonts.poppins()), backgroundColor: EduColors.success),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text('Copy Code', style: GoogleFonts.poppins(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => sp.generateInviteCode(credits: sp.defaultInviteCredits),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text('Regenerate', style: GoogleFonts.poppins(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: sp.canInviteTeachers ? () => sp.generateInviteCode() : null,
                  icon: const Icon(Icons.add),
                  label: Text('Generate Invite Code', style: GoogleFonts.poppins()),
                ),
              ),
              if (!sp.canInviteTeachers && sp.teacherCount >= sp.maxTeachers - 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Teacher limit reached. Upgrade your plan to add more.',
                    style: GoogleFonts.poppins(fontSize: 12, color: EduColors.error),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Default scans per teacher:', style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textMedium)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: TextEditingController(text: sp.defaultInviteCredits.toString()),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) sp.setDefaultInviteCredits(n);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeachersCard(SubscriptionProvider sp) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: EduColors.royalBlue, size: 20),
                const SizedBox(width: 8),
                Text('Teachers', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: EduColors.textDark)),
              ],
            ),
            const SizedBox(height: 16),
            _buildTeacherRow(Icons.person, 'You (Admin)', subtitle: 'Unlimited scans', isPrimary: true),
            if (_loadingTeachers)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (sp.teachers.isNotEmpty)
              ...sp.teachers.asMap().entries.map((entry) =>
                _buildLocalTeacherCard(sp, entry.key, entry.value))
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No teachers invited yet', style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textLight)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildApiTeachers(SubscriptionProvider sp) {
    return _apiTeachers.asMap().entries.map((entry) {
      final t = entry.value;
      final teacherId = t['id'] as int;
      final name = t['name'] as String;
      final allocated = t['allocatedCredits'] as int? ?? 0;
      final used = t['usedCredits'] as int? ?? 0;
      final percent = allocated > 0 ? used / allocated : 0.0;
      final isLow = allocated > 0 && (allocated - used) <= (allocated * 0.2).round();
      return Column(
        children: [
          const Divider(height: 20),
          _buildTeacherRow(Icons.person_outline, name, subtitle: allocated > 0 ? '$used / $allocated scans' : 'No scans'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: EduColors.surface,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isLow ? EduColors.error : EduColors.royalBlue,
                          ),
                        ),
                      ),
                      if (isLow)
                        Text('Low scans!', style: GoogleFonts.poppins(fontSize: 10, color: EduColors.error)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAllocateDialog(context, teacherId, name, allocated),
                    icon: const Icon(Icons.add, size: 14),
                    label: Text('Assign', style: GoogleFonts.poppins(fontSize: 11)),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildLocalTeacherCard(SubscriptionProvider sp, int index, TeacherAllocation teacher) {
    final percent = teacher.usagePercent;
    return Column(
      children: [
        const Divider(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTeacherRow(
                teacher.isActive ? Icons.person_outline : Icons.person_off,
                teacher.name,
                subtitle: teacher.allocatedScans > 0
                    ? '${teacher.usedScans} / ${teacher.allocatedScans} scans'
                    : 'No scans allocated',
                trailing: teacher.isActive
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: EduColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Active', style: GoogleFonts.poppins(fontSize: 10, color: EduColors.success)),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: EduColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Inactive', style: GoogleFonts.poppins(fontSize: 10, color: EduColors.error)),
                      ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'allocate':
                    _showAllocateLocalDialog(context, sp, index, teacher);
                    break;
                  case 'toggle':
                    sp.toggleTeacherActive(index);
                    break;
                  case 'remove':
                    _confirmRemove(context, sp, index, teacher);
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'allocate', child: ListTile(
                  leading: Icon(Icons.monetization_on, color: EduColors.royalBlue),
                  title: Text('Allocate Scans', style: GoogleFonts.poppins()),
                  dense: true,
                )),
                PopupMenuItem(value: 'toggle', child: ListTile(
                  leading: Icon(teacher.isActive ? Icons.block : Icons.check_circle,
                      color: teacher.isActive ? EduColors.error : EduColors.success),
                  title: Text(teacher.isActive ? 'Deactivate' : 'Reactivate', style: GoogleFonts.poppins()),
                  dense: true,
                )),
                PopupMenuItem(value: 'remove', child: ListTile(
                  leading: Icon(Icons.delete, color: EduColors.error),
                  title: Text('Remove', style: GoogleFonts.poppins()),
                  dense: true,
                )),
              ],
            ),
          ],
        ),
        if (teacher.allocatedScans > 0) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: EduColors.surface,
                valueColor: AlwaysStoppedAnimation<Color>(
                  teacher.isLowOnScans ? EduColors.error : EduColors.royalBlue,
                ),
              ),
            ),
          ),
          if (teacher.isLowOnScans)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text('⚠ ${teacher.remainingScans} scans remaining — low!',
                  style: GoogleFonts.poppins(fontSize: 10, color: EduColors.error)),
            ),
        ],
        if (teacher.institutionName != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Row(
              children: [
                Icon(Icons.business, size: 12, color: EduColors.textLight),
                const SizedBox(width: 4),
                Text(teacher.institutionName!, style: GoogleFonts.poppins(fontSize: 10, color: EduColors.textLight)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTeacherRow(IconData icon, String label,
      {String? subtitle, bool isPrimary = false, Widget? trailing}) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: isPrimary ? EduColors.royalBlue : EduColors.surface,
          child: Icon(icon, size: 18, color: isPrimary ? Colors.white : EduColors.textMedium),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(label, style: GoogleFonts.poppins(
                      fontSize: 14, color: EduColors.textDark,
                      fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                    ), overflow: TextOverflow.ellipsis),
                  ),
                  if (isPrimary) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: EduColors.royalBlueLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Admin', style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w500, color: EduColors.royalBlue,
                      )),
                    ),
                  ],
                  if (trailing != null) ...[const SizedBox(width: 8), trailing],
                ],
              ),
              if (subtitle != null)
                Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: EduColors.textMedium)),
            ],
          ),
        ),
      ],
    );
  }

  void _showAllocateLocalDialog(BuildContext context, SubscriptionProvider sp, int index, TeacherAllocation teacher) {
    final ctrl = TextEditingController(text: '30');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Scans — ${teacher.name}', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (teacher.allocatedScans > 0)
              Text('Current: ${teacher.usedScans} used / ${teacher.allocatedScans} allocated (${teacher.remainingScans} remaining)',
                  style: GoogleFonts.poppins(fontSize: 12, color: EduColors.textMedium)),
            const SizedBox(height: 8),
            Text('Enter additional scans to add to this teacher\'s balance.',
                style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Additional scans',
                prefixIcon: Icon(Icons.monetization_on, color: EduColors.royalBlue),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text);
              if (n == null || n <= 0) return;
              sp.allocateScans(index, n);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$n scans added to ${teacher.name}', style: GoogleFonts.poppins()),
                    backgroundColor: EduColors.success),
              );
            },
            child: Text('Add Scans', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showAllocateDialog(BuildContext context, int teacherId, String teacherName, int currentAllocated) {
    final ctrl = TextEditingController(text: currentAllocated > 0 ? currentAllocated.toString() : '30');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign Scans to $teacherName', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set the number of scans. Previous usage will be reset.',
                style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of scans',
                prefixIcon: Icon(Icons.monetization_on, color: EduColors.royalBlue),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () async {
              final credits = int.tryParse(ctrl.text) ?? 0;
              if (credits <= 0) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                messenger.showSnackBar(SnackBar(
                  content: Text('$credits scans assigned to $teacherName', style: GoogleFonts.poppins()),
                  backgroundColor: EduColors.success,
                ));
              } catch (e) {
                if (context.mounted) {
                  showErrorDialog(context, ErrorDialogConfig(
                    title: 'Assignment Failed',
                    message: 'Unable to assign scans. Please try again.',
                    type: ErrorDialogType.error,
                  ));
                }
              }
            },
            child: Text('Assign', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, SubscriptionProvider sp, int index, TeacherAllocation teacher) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${teacher.name}?', style: GoogleFonts.poppins()),
        content: Text('This will permanently remove this teacher from your team.',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              sp.removeTeacher(index);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: EduColors.error, foregroundColor: Colors.white),
            child: Text('Remove', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeSection(SubscriptionProvider sp) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: EduColors.royalBlueLight,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.workspace_premium, size: 28, color: EduColors.royalBlue),
            ),
            const SizedBox(height: 12),
            Text(
              sp.currentPlanId == 'basic' ? 'Upgrade Your Plan' : '${sp.currentPlan?.name ?? 'Current'} Plan',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: EduColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              sp.currentPlanId == 'basic'
                  ? 'Invite teachers and unlock more features'
                  : 'View available plans and upgrade to get more scans and teachers',
              style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium), textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: () => GoRouter.of(context).push('/purchase'),
                icon: const Icon(Icons.workspace_premium),
                label: Text(
                  sp.currentPlanId == 'basic' ? 'View Plans' : 'Upgrade Plan',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EduColors.royalBlue, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesSection(BuildContext context, CourseProvider cp, SubscriptionProvider sp) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.book, color: EduColors.royalBlue, size: 20),
                    const SizedBox(width: 8),
                    Text('Courses', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: EduColors.textDark)),
                  ],
                ),
                if (sp.currentPlanId != 'basic')
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: EduColors.royalBlue),
                    onPressed: () => _showAddCourseDialog(context, cp),
                    tooltip: 'Add course',
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Registered courses available for mark extraction',
                style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium)),
            const SizedBox(height: 16),
            if (cp.courses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    sp.currentPlanId == 'basic' ? 'Upgrade to register courses' : 'No courses registered yet',
                    style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textLight),
                  ),
                ),
              )
            else
              ...cp.courses.asMap().entries.map((entry) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: EduColors.royalBlueLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(entry.value.code, style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.bold, color: EduColors.royalBlue,
                          )),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(entry.value.name, style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textDark)),
                        ),
                        if (sp.currentPlanId != 'basic')
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline, color: EduColors.error, size: 20),
                            onPressed: () => cp.removeCourse(entry.key),
                            tooltip: 'Remove course',
                          ),
                      ],
                    ),
                    if (entry.key < cp.courses.length - 1) const Divider(height: 16),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  void _showAddCourseDialog(BuildContext context, CourseProvider cp) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Register Course', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Course Code (e.g. CSC101)',
                prefixIcon: Icon(Icons.tag, color: EduColors.royalBlue),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Course Name (e.g. Programming)',
                prefixIcon: Icon(Icons.book, color: EduColors.royalBlue),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              final code = codeCtrl.text.trim();
              final name = nameCtrl.text.trim();
              if (code.isEmpty || name.isEmpty) return;
              cp.addCourse(code, name);
              Navigator.pop(ctx);
            },
            child: Text('Register', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }
}
