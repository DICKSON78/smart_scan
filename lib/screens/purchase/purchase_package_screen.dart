import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/clickpesa_service.dart';
import '../../utils/theme.dart';
import '../../widgets/error_dialog.dart';

class _PricingPlan {
  final String title;
  final String price;
  final int priceAmount;
  final String scans;
  final String devices;
  final String description;
  final bool isPopular;
  final bool isBestValue;
  final String badgeLabel;
  final bool isHighlighted;
  final int scanAmount;

  const _PricingPlan({
    required this.title,
    required this.price,
    required this.priceAmount,
    required this.scans,
    required this.devices,
    required this.description,
    this.isPopular = false,
    this.isBestValue = false,
    this.badgeLabel = '',
    this.isHighlighted = false,
    required this.scanAmount,
  });
}

const _plans = [
  _PricingPlan(
    title: 'Starter',
    price: 'Tshs 25,000',
    priceAmount: 25000,
    scans: '1,000 Scans',
    devices: 'Up to 2 Devices',
    description: 'Perfect for individual lecturers',
    scanAmount: 1000,
  ),
  _PricingPlan(
    title: 'Standard',
    price: 'Tshs 100,000',
    priceAmount: 100000,
    scans: '5,000 Scans',
    devices: 'Up to 5 Devices',
    description: 'Active lecturers with multiple courses',
    scanAmount: 5000,
  ),
  _PricingPlan(
    title: 'Institution',
    price: 'Tshs 800,000',
    priceAmount: 800000,
    scans: '50,000 Scans',
    devices: 'Up to 100 Devices',
    description: 'Universities and colleges',
    isBestValue: true,
    badgeLabel: 'BEST VALUE',
    isHighlighted: true,
    scanAmount: 50000,
  ),
  _PricingPlan(
    title: 'Unlimited',
    price: 'Tshs 1,300,000',
    priceAmount: 1300000,
    scans: '200,000 Scans',
    devices: 'Up to 200 Devices',
    description: 'Large multi-faculty institutions',
    scanAmount: 200000,
  ),
];

class PurchasePackageScreen extends StatefulWidget {
  const PurchasePackageScreen({super.key});

  @override
  State<PurchasePackageScreen> createState() => _PurchasePackageScreenState();
}

class _PurchasePackageScreenState extends State<PurchasePackageScreen> {
  final ClickPesaService _clickPesa = ClickPesaService();
  bool _isPaying = false;

  @override
  void dispose() {
    _clickPesa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: EduColors.offWhite,
      appBar: AppBar(
        title: const Text('Subscription & Credits'),
        backgroundColor: EduColors.white,
        elevation: 0,
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, sp, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            children: [
              _buildHeader(auth),
              const SizedBox(height: 28),
              ..._plans.map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _PricingCard(
                  plan: plan,
                  sp: sp,
                  onBuy: () => _onBuy(context, plan),
                  isPaying: _isPaying,
                ),
              )),
              const SizedBox(height: 8),
              _buildCurrentPlanNote(sp),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AuthProvider auth) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: EduColors.royalBlueLight.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.workspace_premium, size: 40, color: EduColors.royalBlue),
        ),
        const SizedBox(height: 16),
        Text(
          'Choose Your Plan',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: EduColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Unlock more scans and devices',
          style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textMedium),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: EduColors.royalBlueLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EduColors.royalBlue.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet, size: 18, color: EduColors.royalBlue),
              const SizedBox(width: 8),
              Text(
                '${auth.credits} scans remaining',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: EduColors.royalBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentPlanNote(SubscriptionProvider sp) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EduColors.royalBlueLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EduColors.royalBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: EduColors.royalBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are on the ${sp.currentPlan?.name ?? 'Basic'} plan. Switch anytime to unlock more.',
              style: GoogleFonts.poppins(fontSize: 13, color: EduColors.royalBlue),
            ),
          ),
        ],
      ),
    );
  }

  void _onBuy(BuildContext context, _PricingPlan plan) {
    _showPaymentSheet(context, plan);
  }

  void _showPaymentSheet(BuildContext context, _PricingPlan plan) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EduColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Payment Method',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: EduColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${plan.title} - ${plan.price}',
              style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textMedium),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _doMobilePayment(context, plan);
                },
                icon: const Icon(Icons.phone_android),
                label: Text(
                  'Mobile Money',
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
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
                child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCardPaymentDialog(context, plan);
                },
                icon: const Icon(Icons.account_balance),
                label: Text(
                  'Bank Payment',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EduColors.royalBlue,
                  side: const BorderSide(color: EduColors.royalBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: EduColors.textLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCardPaymentDialog(BuildContext context, _PricingPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EduColors.royalBlueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance, size: 32, color: EduColors.royalBlue),
            ),
            const SizedBox(height: 16),
            Text(
              'Bank Payment',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: EduColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              '${plan.title} - ${plan.price}',
              style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textMedium),
            ),
            const SizedBox(height: 12),
            Text(
              'Card payments will be available soon. Please use Mobile Money for now.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _doMobilePayment(context, plan);
                },
                icon: const Icon(Icons.phone_android),
                label: Text(
                  'Use Mobile Money Instead',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EduColors.royalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: EduColors.textLight)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPaymentWaitingCard(BuildContext context, _PricingPlan plan) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              'Card payments are coming soon!',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'For now, please use Mobile Money to complete your payment.',
              style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showPaymentSheet(context, plan);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: EduColors.royalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: Text('Use Mobile Money', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: EduColors.textLight)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doMobilePayment(BuildContext context, _PricingPlan plan) async {
    final phoneCtrl = TextEditingController();
    final confirmed = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EduColors.royalBlueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.phone_android, size: 32, color: EduColors.royalBlue),
            ),
            const SizedBox(height: 16),
            Text(
              'Mobile Payment',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: EduColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              '${plan.title} - ${plan.price}',
              style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textMedium),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g. 0789 123 456',
                prefixIcon: const Icon(Icons.phone, color: EduColors.royalBlue),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final phone = phoneCtrl.text.trim();
                  if (phone.isEmpty) return;
                  Navigator.pop(ctx, phone);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: EduColors.royalBlue,
                  foregroundColor: Colors.white,
                  overlayColor: EduColors.white.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Pay Now',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: EduColors.textLight)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (confirmed == null || confirmed.isEmpty) return;

    await _processPayment(context, plan, confirmed);
  }

  Future<void> _processPayment(BuildContext context, _PricingPlan plan, String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    final sp = context.read<SubscriptionProvider>();

    setState(() => _isPaying = true);

    try {
      // 1. Initiate payment
      final result = await _clickPesa.initiateUSSDPush(
        uid: auth.user?.id ?? '',
        planId: plan.title.toLowerCase(),
        amount: plan.priceAmount,
        scans: plan.scanAmount,
        phone: phone,
      );

      if (!result.success || result.orderReference == null) {
        final errorMsg = result.error ?? 'Failed to initiate payment';
        if (mounted) {
          showErrorDialog(context, ErrorDialogConfig(
            title: 'Payment Failed',
            message: _friendlyPaymentError(errorMsg),
            actionLabel: 'Try Again',
            onAction: () => _showPaymentSheet(context, plan),
            secondaryLabel: 'Cancel',
            type: ErrorDialogType.error,
          ));
        }
        return;
      }

      // 2. Show waiting dialog and poll ClickPesa for status
      if (!mounted) return;
      final paymentOk = await _showPaymentWaitingDialog(
        context,
        orderRef: result.orderReference!,
        plan: plan,
      );

      if (paymentOk) {
        // 3. Payment confirmed — _clickPesa.pollForPayment already credited Firestore
        // Refresh full user profile (credits + isAdmin status)
        await auth.refreshUserProfile();
        sp.selectPlan(plan.title.toLowerCase());

        // Institution plan: ask for institution name
        if (plan.title.toLowerCase() == 'institution' && mounted) {
          await _showInstitutionDialog(context, auth);
        }

        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Payment successful! ${plan.title} activated. ${_formatScans(plan.scanAmount)} scans added.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: EduColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, ErrorDialogConfig(
          title: 'Payment Error',
          message: 'We could not process your payment. Please check your internet connection and try again.',
          actionLabel: 'Try Again',
          onAction: () => _showPaymentSheet(context, plan),
          secondaryLabel: 'Cancel',
          type: ErrorDialogType.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  String _friendlyPaymentError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('network') || lower.contains('internet')) return 'Unable to connect. Please check your internet connection and try again.';
    if (lower.contains('timed out')) return 'Connection timed out. Please check your internet and try again.';
    if (lower.contains('authentication') || lower.contains('auth')) return raw;
    if (lower.contains('payment service')) return raw;
    if (lower.contains('invalid phone') || lower.contains('phone')) return 'Please enter a valid phone number.';
    if (lower.contains('minimum')) return raw;
    return 'Something went wrong. Please try again.';
  }

  Future<void> _showInstitutionDialog(BuildContext context, AuthProvider auth) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Institution Name',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: EduColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your institution name. This will be used for your team invite codes.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: EduColors.textMedium,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. University of Dar es Salaam',
                prefixIcon: const Icon(Icons.business_outlined, color: EduColors.royalBlue),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: EduColors.textLight),
                    ),
                    child: Text('Skip', style: GoogleFonts.poppins(color: EduColors.textMedium)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Save', style: GoogleFonts.poppins()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      try {
        await auth.updateProfile(institutionName: result);
      } catch (_) {}
    }
    controller.dispose();
  }

  Future<bool> _showPaymentWaitingDialog(
    BuildContext context, {
    required String orderRef,
    required _PricingPlan plan,
  }) async {
    // ignore: use_build_context_synchronously
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PaymentWaitingDialog(
        orderRef: orderRef,
        planName: plan.title,
        amount: plan.price,
        clickPesa: _clickPesa,
      ),
    ).then((result) => result ?? false);
  }

  String _formatScans(int amount) {
    if (amount >= 999999) return 'Unlimited';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)},000';
    return amount.toString();
  }
}

// ---------- Payment Waiting Dialog ----------

class _PaymentWaitingDialog extends StatefulWidget {
  final String orderRef;
  final String planName;
  final String amount;
  final ClickPesaService clickPesa;

  const _PaymentWaitingDialog({
    required this.orderRef,
    required this.planName,
    required this.amount,
    required this.clickPesa,
  });

  @override
  State<_PaymentWaitingDialog> createState() => _PaymentWaitingDialogState();
}

class _PaymentWaitingDialogState extends State<_PaymentWaitingDialog> {
  bool _isPolling = true;
  bool _success = false;
  String _statusMessage = 'Waiting for payment...';

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  Future<void> _startPolling() async {
    final ok = await widget.clickPesa.pollForPayment(widget.orderRef);

    if (!mounted) return;

    if (ok) {
      setState(() {
        _success = true;
        _isPolling = false;
        _statusMessage = 'Payment confirmed!';
      });
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        _isPolling = false;
        _statusMessage = 'Payment timed out or failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isPolling) ...[
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              Text(
                'Processing Payment',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: EduColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.planName} - ${widget.amount}',
                style: GoogleFonts.poppins(fontSize: 14, color: EduColors.textMedium),
              ),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your PIN when prompted',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: EduColors.textLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ] else if (_success) ...[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: EduColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 32, color: EduColors.success),
              ),
              const SizedBox(height: 16),
              Text(
                'Payment Successful!',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: EduColors.success,
                ),
              ),
            ] else ...[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: EduColors.errorLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 32, color: EduColors.error),
              ),
              const SizedBox(height: 16),
              Text(
                'Payment Failed',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: EduColors.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: EduColors.textMedium),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EduColors.royalBlue,
                    foregroundColor: Colors.white,
                    overlayColor: EduColors.white.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------- Pricing Card ----------

class _PricingCard extends StatelessWidget {
  final _PricingPlan plan;
  final SubscriptionProvider sp;
  final VoidCallback onBuy;
  final bool isPaying;

  const _PricingCard({
    required this.plan,
    required this.sp,
    required this.onBuy,
    required this.isPaying,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = sp.currentPlanId == plan.title.toLowerCase();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: EduColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isHighlighted
              ? EduColors.royalBlue.withValues(alpha: 0.5)
              : EduColors.cardBorder,
          width: plan.isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _buildCardBody(isActive),
              ),
              if (plan.badgeLabel.isNotEmpty)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _DiagonalRibbon(
                    label: plan.badgeLabel,
                    isBlue: plan.isPopular,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _buildButton(context, isActive),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBody(bool isActive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              plan.title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: EduColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              plan.price,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: EduColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildFeatureRow(
          Icons.check,
          plan.scans,
          isUnlimited: plan.title == 'Unlimited',
        ),
        const SizedBox(height: 12),
        _buildFeatureRow(
          Icons.shield_outlined,
          plan.devices,
        ),
        const SizedBox(height: 20),
        Divider(
          color: EduColors.cardBorder,
          thickness: 1,
          height: 1,
        ),
        const SizedBox(height: 16),
        Text(
          plan.description,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: EduColors.textMedium,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, {bool isUnlimited = false}) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: icon == Icons.check
                ? EduColors.successLight
                : EduColors.royalBlueLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: icon == Icons.check
                ? EduColors.success
                : EduColors.royalBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isUnlimited ? FontWeight.bold : FontWeight.normal,
              color: EduColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(BuildContext context, bool isActive) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (isActive || isPaying) ? null : onBuy,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? EduColors.cardBorder
              : plan.isHighlighted
                  ? EduColors.royalBlue
                  : EduColors.royalBlue.withValues(alpha: 0.85),
          foregroundColor: isActive ? EduColors.textLight : EduColors.white,
          disabledBackgroundColor: EduColors.cardBorder,
          disabledForegroundColor: EduColors.textLight,
          overlayColor: EduColors.white.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0,
        ),
        child: Text(
          isPaying
              ? 'Processing...'
              : isActive
                  ? 'Current Plan'
                  : 'Activate',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _DiagonalRibbon extends StatelessWidget {
  final String label;
  final bool isBlue;

  const _DiagonalRibbon({required this.label, required this.isBlue});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _RibbonClipper(),
      child: SizedBox(
        width: 100,
        height: 100,
        child: Transform.translate(
          offset: const Offset(24, -24),
          child: Transform.rotate(
            angle: 0.785,
            child: Container(
              width: 100,
              height: 26,
              decoration: BoxDecoration(
                color: isBlue ? EduColors.royalBlue : EduColors.success,
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(size.width - 40, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 40)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
