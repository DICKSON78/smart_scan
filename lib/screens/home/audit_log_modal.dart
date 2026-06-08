import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/theme.dart';
import '../../models/audit_entry.dart';
import '../../providers/audit_provider.dart';
import '../../widgets/dialog_header.dart';
import 'package:provider/provider.dart';

class AuditLogModal extends StatelessWidget {
  const AuditLogModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Consumer<AuditProvider>(
        builder: (context, audit, _) {
          final logs = audit.logs;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          DialogHeader(
            icon: Icons.security,
            title: 'Security Audit Trail',
            count: logs.length,
          ),
              if (logs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: EduColors.textLight),
                      const SizedBox(height: 12),
                      Text('No audit entries yet',
                          style: GoogleFonts.poppins(color: EduColors.textMedium)),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final entry = logs[index];
                      return _buildAuditRow(entry);
                    },
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: EduColors.cardBorder)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Records are immutable',
                        style: GoogleFonts.poppins(fontSize: 11, color: EduColors.textLight),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close', style: GoogleFonts.poppins(color: EduColors.royalBlue)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAuditRow(AuditEntry entry) {
    Color actionColor;
    IconData actionIcon;
    switch (entry.action) {
      case 'EXTRACT':
        actionColor = EduColors.success;
        actionIcon = Icons.download;
        break;
      case 'EDIT':
        actionColor = EduColors.warning;
        actionIcon = Icons.edit;
        break;
      case 'DELETE':
        actionColor = EduColors.error;
        actionIcon = Icons.delete;
        break;
      default:
        actionColor = EduColors.royalBlue;
        actionIcon = Icons.add_circle;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EduColors.offWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: actionColor, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: actionColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(actionIcon, size: 16, color: actionColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.details,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: EduColors.textDark),
                  ),
                  if (entry.oldValue != null && entry.newValue != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${entry.oldValue} \u2192 ${entry.newValue}',
                      style: GoogleFonts.poppins(fontSize: 11, color: EduColors.textMedium),
                    ),
                  ],
                  Text(
                    _formatTime(entry.timestamp),
                    style: GoogleFonts.poppins(fontSize: 10, color: EduColors.textLight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
