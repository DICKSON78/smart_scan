import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';

enum DialogType { error, warning, info, success }

typedef ErrorDialogType = DialogType;

class ErrorDialogConfig {
  final String title;
  final String message;
  final DialogType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const ErrorDialogConfig({
    required this.title,
    required this.message,
    this.type = DialogType.error,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });
}

Future<void> showErrorDialog(BuildContext context, ErrorDialogConfig config) {
  return showDialog(
    context: context,
    builder: (_) => ErrorDialog(
      title: config.title,
      message: config.message,
      type: config.type,
      actionLabel: config.actionLabel,
      onAction: config.onAction,
      secondaryLabel: config.secondaryLabel,
      onSecondary: config.onSecondary,
    ),
  );
}

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final DialogType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.type = DialogType.error,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = switch (type) {
      DialogType.error => Icons.error_outline,
      DialogType.warning => Icons.warning_amber_rounded,
      DialogType.info => Icons.info_outline,
      DialogType.success => Icons.check_circle_outline,
    };

    final iconColor = switch (type) {
      DialogType.error => EduColors.error,
      DialogType.warning => EduColors.warning,
      DialogType.info => EduColors.royalBlue,
      DialogType.success => EduColors.success,
    };

    final bgColor = switch (type) {
      DialogType.error => const Color(0xFFFEE2E2),
      DialogType.warning => const Color(0xFFFEF3C7),
      DialogType.info => const Color(0xFFFFF0E6),
      DialogType.success => const Color(0xFFD1FAE5),
    };

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, size: 32, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: EduColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: EduColors.textMedium,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            if (actionLabel != null)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onAction?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EduColors.royalBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    actionLabel!,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            if (actionLabel != null && secondaryLabel != null) const SizedBox(height: 8),
            if (secondaryLabel != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onSecondary?.call();
                },
                child: Text(
                  secondaryLabel!,
                  style: GoogleFonts.poppins(color: EduColors.textLight),
                ),
              ),
            if (actionLabel == null && secondaryLabel == null)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EduColors.royalBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
