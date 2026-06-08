import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class _PricingPlan {
  final String title;
  final String price;
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
    scans: '1,000 Scans',
    devices: 'Up to 2 Devices',
    description: 'Perfect for individual lecturers',
    scanAmount: 1000,
  ),
  _PricingPlan(
    title: 'Standard',
    price: 'Tshs 100,000',
    scans: '5,000 Scans',
    devices: 'Up to 5 Devices',
    description: 'Active lecturers with multiple courses',
    scanAmount: 5000,
  ),
  _PricingPlan(
    title: 'School',
    price: 'Tshs 180,000',
    scans: '10,000 Scans',
    devices: 'Up to 20 Devices',
    description: 'Small schools and departments',
    isPopular: true,
    badgeLabel: 'POPULAR',
    isHighlighted: true,
    scanAmount: 10000,
  ),
  _PricingPlan(
    title: 'Institution',
    price: 'Tshs 800,000',
    scans: '50,000 Scans',
    devices: 'Up to 100 Devices',
    description: 'Universities and colleges',
    isBestValue: true,
    badgeLabel: 'BEST VALUE',
    scanAmount: 50000,
  ),
  _PricingPlan(
    title: 'Unlimited',
    price: 'Tshs 1,300,000',
    scans: 'Unlimited Scans',
    devices: 'Up to 200 Devices',
    description: 'Large multi-faculty institutions — 1 year unlimited',
    scanAmount: 999999,
  ),
];

class PurchasePackageScreen extends StatelessWidget {
  const PurchasePackageScreen({super.key});

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
                child: _PricingCard(plan: plan, sp: sp),
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
              Icon(Icons.bolt, size: 18, color: EduColors.royalBlue),
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
}

class _PricingCard extends StatelessWidget {
  final _PricingPlan plan;
  final SubscriptionProvider sp;

  const _PricingCard({required this.plan, required this.sp});

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
        onPressed: isActive
            ? null
            : () => _onBuy(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? EduColors.cardBorder
              : plan.isHighlighted
                  ? EduColors.royalBlue
                  : EduColors.royalBlue.withValues(alpha: 0.85),
          foregroundColor: isActive ? EduColors.textLight : EduColors.white,
          disabledBackgroundColor: EduColors.cardBorder,
          disabledForegroundColor: EduColors.textLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0,
        ),
        child: Text(
          isActive ? 'Current Plan' : 'Activate',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  void _onBuy(BuildContext context) {
    _showPaymentSheet(context);
  }

  void _showPaymentSheet(BuildContext context) {
    final planKey = plan.title.toLowerCase();
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
                  _completePurchase(context, planKey, 'bank');
                },
                icon: const Icon(Icons.account_balance),
                label: Text(
                  'Bank Card Payment',
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
                  _showMobilePaymentDialog(context, planKey);
                },
                icon: const Icon(Icons.phone_android),
                label: Text(
                  'Mobile Payment',
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

  void _showMobilePaymentDialog(BuildContext context, String planKey) {
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'e.g. 0789 123 456',
                  prefixIcon: const Icon(Icons.phone, color: EduColors.royalBlue),
                  border: OutlineInputBorder(),
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
                    Navigator.pop(ctx);
                    _completePurchase(context, planKey, 'mobile');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EduColors.royalBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: Text(
                    'Subscribe Now',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
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
      ),
    );
  }

  Future<void> _completePurchase(BuildContext context, String planKey, String method) async {
    final messenger = ScaffoldMessenger.of(context);
    final sp = context.read<SubscriptionProvider>();
    final auth = context.read<AuthProvider>();

    try {
      sp.selectPlan(planKey);
      await auth.addCredits(plan.scanAmount);
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${plan.title} activated! ${_formatScans(plan.scanAmount)} scans added.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: EduColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Purchase failed: $e', style: GoogleFonts.poppins()),
            backgroundColor: EduColors.error,
          ),
        );
      }
    }
  }

  String _formatScans(int amount) {
    if (amount >= 999999) return 'Unlimited';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)},000';
    return amount.toString();
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
