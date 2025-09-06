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
  bool _isCancelling = false;

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
        // IMPORTANT: verify server-side (do not trust client-only)
        try {
          final verifyRes = await SupabaseService.instance.verifyTransaction(
            reference,
          );

          // verify function should return { ok: true, data: tx } on success
          if (verifyRes['ok'] == true) {
            // success -> navigate to success screen (server already persisted and marked premium)
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const PaymentSuccessScreen(),
              ),
              (route) => false,
            );
          } else {
            // verification failed/pending: show friendly error
            final reason =
                verifyRes['error'] ??
                verifyRes['reason'] ??
                verifyRes.toString();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment verification failed: $reason'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _handleCancelSubscription() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to manage subscriptions.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel subscription'),
        content: const Text(
          'Are you sure you want to cancel your subscription? This will stop future recurring charges.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isCancelling = true);

    try {
      // 1) fetch profile to get subscription code
      final profile = await SupabaseService.instance.fetchUserProfile(user.uid);
      final subscriptionCode = (profile['current_subscription_code'] as String?)
          ?.trim();

      if (subscriptionCode == null || subscriptionCode.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active subscription found for your account.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 2) call cancel edge function
      final functionUrl =
          'https://stgykupephpnlshzvfwn.supabase.co/functions/v1/cancel-subscription';
      final result = await SupabaseService.instance
          .cancelSubscriptionServerSide(
            subscriptionCode: subscriptionCode,
            userId: user.uid,
            functionUrl: functionUrl,
          );

      // 3) handle response
      if (result['ok'] == true) {
        if (!mounted) return;
        // reflect UI and reload profile
        await _loadUserData();
        setState(() => _isPremium = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription cancelled successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final reason =
            result['error'] ?? result['disabled'] ?? result.toString();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancel failed: $reason'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling subscription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
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
          // Primary purchase/subscribed button + optional Cancel button below
          Column(
            children: [
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
              const SizedBox(height: 8),
              // Show Cancel subscription only when user is premium and this is the paid plan
              if (isPlusPlan && _isPremium)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isCancelling ? null : _handleCancelSubscription,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white10),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isCancelling
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Cancel subscription',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
