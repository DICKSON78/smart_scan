import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/theme.dart';

class HomeHeader extends StatelessWidget {
  final String sessionName;
  final VoidCallback onSwitchSession;
  final VoidCallback onViewAudit;

  const HomeHeader({
    super.key,
    required this.sessionName,
    required this.onSwitchSession,
    required this.onViewAudit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: EduColors.royalBlue,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: EduColors.royalBlue.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(Icons.document_scanner, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'SmartScan Marks',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: EduColors.textDark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'v1.3',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: EduColors.textLight,
                    ),
                  ),
                ],
              ),
              Text(
                'OCR-Powered Mark Extraction',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: EduColors.textMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildAuditButton(),
        const SizedBox(width: 8),
        _buildSessionBadge(),
      ],
    );
  }

  Widget _buildAuditButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onViewAudit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: EduColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EduColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: EduColors.royalBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Audit',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: EduColors.textMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: EduColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EduColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Active Session',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: EduColors.textLight,
                ),
              ),
              Text(
                sessionName,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: EduColors.royalBlue,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onSwitchSession,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: EduColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Switch',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: EduColors.textMedium,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
