import 'package:flutter/material.dart';
import 'package:studywithcharles/shared/services/auth_service.dart';
import 'package:studywithcharles/shared/services/supabase_service.dart';
import 'package:studywithcharles/features/pricing/presentation/payment_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:studywithcharles/features/pricing/presentation/payment_success_screen.dart';

// --- NEW IMPORTS FOR WEB PAYMENTS ---
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher_string.dart';
// ------------------------------------

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});
  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool _yearly = false; // Toggles between Monthly and Yearly
  bool _isLoading = true;
  bool _isProcessingPayment = false; // Locks one button when paying
  bool _isCancelling = false; // Locks the cancel button
  String _email = '';
  String _subscriptionTier = 'free';

  // These are your new Plan Codes.
  final Map<String, String> _planCodes = {
    'plus_monthly': 'PLN_gapbsk8t3695ggo',
    'plus_yearly': 'PLN_qotjx6a3eg2fzf92',
    'pro_monthly': 'PLN_mb1kdfkm5hplvj3',
    'pro_yearly': 'PLN_6kr1djeohqve333',
  };

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
          _subscriptionTier = profile['subscription_tier'] as String? ?? 'free';
          _email = user.email!;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NEW VERIFY HELPER (FROM YOUR FRIEND'S ADVICE) ---
  // This will poll the backend to see if the payment (in the other tab) was successful
  Future<void> _verifyAndHandleResult(String reference) async {
    // Show a loading indicator while we verify
    setState(() => _isProcessingPayment = true);

    const int maxAttempts = 10;
    const Duration waitBetween = Duration(seconds: 3);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final verifyRes = await SupabaseService.instance.verifyTransaction(
          reference,
        );
        if (verifyRes['ok'] == true) {
          // SUCCESS!
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (c) => const PaymentSuccessScreen()),
            (route) => false,
          );
          return; // Exit the function on success
        } else {
          // Payment not successful yet, wait and retry
          debugPrint('Verification attempt ${attempt + 1} failed, retrying...');
        }
      } catch (e) {
        // Ignore transient errors and keep trying
        debugPrint('Verification attempt ${attempt + 1} threw error: $e');
      }

      // Don't wait after the last attempt
      if (attempt < maxAttempts - 1) {
        await Future.delayed(waitBetween);
      }
    }

    // If loop finishes without success, show an error
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Payment not verified. If you paid, please restart the app or contact support.',
        ),
        backgroundColor: Colors.red,
      ),
    );
    setState(() => _isProcessingPayment = false);
  }
  // --------------------------------------------------------

  // --- UPDATED _handlePayment with WEB vs MOBILE logic ---
  Future<void> _handlePayment(String planCode, String tierName) async {
    final user = AuthService.instance.currentUser;

    if (_email.isEmpty || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User session error. Please log out and log in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isProcessingPayment) return;

    setState(() => _isProcessingPayment = true);

    final reference = 'swc_${const Uuid().v4()}';

    try {
      final paymentUrl = await SupabaseService.instance
          .initializePaystackTransaction(
            planCode,
            tierName,
            _email,
            reference,
            user.uid,
          );

      if (!mounted) return;

      // --- THIS IS THE NEW LOGIC ---
      if (kIsWeb) {
        // On WEB: Open in a new tab
        await launchUrlString(paymentUrl, webOnlyWindowName: '_blank');

        // Show a dialog telling the user what to do
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false, // User must make a choice
          builder: (ctx) => AlertDialog(
            title: const Text('Payment Started'),
            content: const Text(
              'We opened your payment in a new browser tab. Once you have completed payment, please return to this tab and press "Verify Payment".',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Verify Payment'),
              ),
            ],
          ),
        );

        setState(
          () => _isProcessingPayment = false,
        ); // Stop loading on the button

        if (confirmed == true) {
          // User clicked "Verify", start polling the backend
          await _verifyAndHandleResult(reference);
        }
      } else {
        // On MOBILE: Use the existing WebView screen (no changes needed here)
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) =>
                PaymentScreen(paystackUrl: paymentUrl, reference: reference),
          ),
        );

        if (result == true) {
          // This path is for mobile only now, where redirect brings app back
          // We can just call the verify function once.
          await _verifyAndHandleResult(reference);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment failed or was cancelled.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isProcessingPayment = false);
        }
      }
      // --- END OF NEW LOGIC ---
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isProcessingPayment = false);
    }
    // Removed the "finally" block, since processing state is now handled within the logic paths
  }
  // --------------------------------------------------------

  // This confirmation dialog is unchanged and is fine.
  Future<bool> _showBrandConfirmCancelDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F0F10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Cancel subscription',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to cancel your subscription? This will stop future recurring charges and your account will revert to "Free".',
            style: TextStyle(color: Colors.white70),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No, keep it'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935), // prominent red
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Yes, cancel',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // This cancel logic is unchanged and works with our new functions.
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

    final confirm = await _showBrandConfirmCancelDialog();
    if (!confirm) return;
    if (!mounted) return;
    setState(() => _isCancelling = true);

    try {
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
        setState(() => _isCancelling = false); // Add this
        return;
      }

      final functionUrl =
          'https://stgykupephpnlshzvfwn.supabase.co/functions/v1/cancel-subscription';
      final result = await SupabaseService.instance
          .cancelSubscriptionServerSide(
            subscriptionCode: subscriptionCode,
            userId: user.uid,
            functionUrl: functionUrl,
          );

      if (result['ok'] == true) {
        if (!mounted) return;
        await _loadUserData(); // Reload user data to get new 'free' tier status
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
    // This build method is unchanged
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
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
                        value: _yearly,
                        onChanged: (v) => setState(() => _yearly = v),
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
                        _buildPlanCard(
                          title: 'Free',
                          price: '₦0',
                          features: const [
                            'Save up to 3 study cards',
                            'Add 1 username to timetable',
                            'Generate up to 3 images a day',
                            'Upload up to 3 files/images a day',
                          ],
                          tierKey: 'free',
                        ),
                        const SizedBox(height: 16),
                        _buildPlanCard(
                          title: 'Plus',
                          price: _yearly ? '₦12,000 /year' : '₦1,200 /month',
                          features: const [
                            'All Free features, plus:',
                            'Save up to 10 study cards',
                            'Add up to 10 usernames to timetable',
                            'Generate up to 10 images a day',
                            'Upload up to 10 files/images a day',
                            'Vote for The Charles Award winner',
                          ],
                          tierKey: 'plus',
                        ),
                        const SizedBox(height: 16),
                        _buildPlanCard(
                          title: 'Pro',
                          price: _yearly ? '₦50,000 /year' : '₦5,000 /month',
                          features: const [
                            'All Plus features, plus:',
                            'Unlimited study card saves',
                            'Unlimited usernames in timetable',
                            'Unlimited image generations',
                            'Unlimited file/image uploads',
                            'Enjoy all features without limits!',
                          ],
                          tierKey: 'pro',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // This _buildPlanCard function is unchanged
  Widget _buildPlanCard({
    required String title,
    required String price,
    required List<String> features,
    required String tierKey, // 'free', 'plus', or 'pro'
  }) {
    // --- Button Logic ---
    String buttonText;
    VoidCallback? onPressedAction;
    bool showCancelButton = false;
    bool isProcessingThisPlan = false;
    Color buttonColor = Colors.cyanAccent;
    Color textColor = Colors.black;

    if (tierKey == _subscriptionTier) {
      buttonText = 'Current Plan';
      if (tierKey == 'plus' || tierKey == 'pro') {
        showCancelButton = true;
      }
    } else if (tierKey == 'plus' && _subscriptionTier == 'free') {
      buttonText = 'Get Plus';
      onPressedAction = () => _handlePayment(
        _yearly ? _planCodes['plus_yearly']! : _planCodes['plus_monthly']!,
        'plus',
      );
    } else if (tierKey == 'pro' &&
        (_subscriptionTier == 'free' || _subscriptionTier == 'plus')) {
      buttonText = 'Upgrade to Pro';
      onPressedAction = () => _handlePayment(
        _yearly ? _planCodes['pro_yearly']! : _planCodes['pro_monthly']!,
        'pro',
      );
    } else if (tierKey == 'plus' && _subscriptionTier == 'pro') {
      buttonText = 'Included in Pro';
      buttonColor = Colors.white24;
      textColor = Colors.white70;
    } else {
      buttonText = 'Subscribed'; // e.g., Free card when user is Plus/Pro
      buttonColor = Colors.white24;
      textColor = Colors.white70;
    }

    // Check if the payment processing is for THIS plan
    if (_isProcessingPayment && onPressedAction != null) {
      isProcessingThisPlan = true;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (tierKey == 'pro')
              ? Colors.cyanAccent
              : (tierKey == 'plus'
                    ? Colors.cyan.withOpacity(0.5)
                    : Colors.white24),
          width: (tierKey == 'pro') ? 2 : 1,
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
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    disabledBackgroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: isProcessingThisPlan
                      ? null
                      : onPressedAction, // Use the new action
                  child: isProcessingThisPlan
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          buttonText, // Use the new dynamic text
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              if (showCancelButton)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCancelling
                          ? null
                          : _handleCancelSubscription,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935), // rich red
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
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
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
