import 'package:flutter/material.dart';
import 'package:studywithcharles/shared/services/auth_service.dart';
import 'package:studywithcharles/shared/services/supabase_service.dart';
import 'package:studywithcharles/features/pricing/presentation/payment_screen.dart';
import 'package:uuid/uuid.dart';
// UNCOMMENTED this line
import 'package:studywithcharles/features/pricing/presentation/payment_success_screen.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});
  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool yearly = false;
  bool _isPremium = false;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = AuthService.instance.currentUser;
    if (user == null || !mounted) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final profile = await SupabaseService.instance.fetchUserProfile(user.uid);
      if (mounted) {
        setState(() {
          _isPremium = profile['is_premium'] as bool? ?? false;
          _email = user.email!;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePayment() async {
    if (_email.isEmpty || _isProcessingPayment) {
      return;
    }
    setState(() => _isProcessingPayment = true);

    final amountInKobo = yearly ? 1200000 : 120000;
    final reference = 'swc_${const Uuid().v4()}';

    try {
      final paymentUrl = await SupabaseService.instance
          .initializePaystackTransaction(amountInKobo, _email, reference);

      if (!mounted) return;

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) =>
              PaymentScreen(paystackUrl: paymentUrl, reference: reference),
        ),
      );

      if (result == true) {
        // --- THIS IS THE NEW LOGIC ---
        // 1. Mark the user as premium in the database
        await SupabaseService.instance.markUserAsPremium();
        // 2. Add a small delay for stability
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        // 3. Navigate to the success screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PaymentSuccessScreen()),
          (route) => false,
        );
        // -----------------------------
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment failed or was cancelled.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // This build method does not need changes
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Pricing',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Monthly',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Switch(
                        value: yearly,
                        onChanged: (v) => setState(() => yearly = v),
                        activeColor: Colors.cyanAccent,
                      ),
                      const Text(
                        'Yearly (Save 2 months!)',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildPlanCard('Free', '₦0', [
                          'Create study cards',
                          'Organize your timetable',
                        ], false),
                        const SizedBox(height: 16),
                        _buildPlanCard(
                          'Plus',
                          yearly ? '₦12,000 /year' : '₦1,200 /month',
                          [
                            'All Free features, plus:',
                            'Share your timetable with friends',
                            'Vote for The Charles Award winner',
                            'Higher chance of TCA nomination',
                            'Save unlimited study cards',
                          ],
                          true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard(
    String title,
    String price,
    List<String> features,
    bool isPaid,
  ) {
    // This widget does not need changes
    final bool isPlusPlan = isPaid;
    final bool canPurchase = isPlusPlan && !_isPremium;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlusPlan ? Colors.cyanAccent : Colors.white24,
          width: isPlusPlan ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          for (var f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 20, color: Colors.cyanAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canPurchase
                    ? Colors.cyanAccent
                    : Colors.white24,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: canPurchase ? _handlePayment : null,
              child: _isProcessingPayment && isPlusPlan
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      isPlusPlan
                          ? (_isPremium ? 'Subscribed' : 'Get Plus')
                          : 'Current Plan',
                      style: TextStyle(
                        color: canPurchase ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
