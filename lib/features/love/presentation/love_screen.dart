import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:studywithcharles/shared/services/auth_service.dart';
import 'package:studywithcharles/shared/services/supabase_service.dart';

class LoveSectionScreen extends StatefulWidget {
  const LoveSectionScreen({super.key});

  @override
  State<LoveSectionScreen> createState() => _LoveSectionScreenState();
}

class _LoveSectionScreenState extends State<LoveSectionScreen> {
  bool _isLoading = true;
  bool _showWriteUp = false;
  bool _isPremium = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int? _selectedNomineeIndex;

  // State variables to hold live data from Supabase
  Map<String, dynamic>? _activeCycle;
  List<Map<String, dynamic>> _pastWinners = [];
  List<Map<String, dynamic>> _nominees = [];
  final List<String> _pageTitles = [
    'Election',
    'Achievements',
    'Elders’ Suggestions',
  ];
  // We will add elder proposals later

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPremiumStatus();
      _fetchLoveSectionData();
    });

    _pageController.addListener(() {
      final page = (_pageController.page ?? 0).round();
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // We will replace this with a real check from your database later.
  Future<void> _checkPremiumStatus() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !mounted) return;

    try {
      final profile = await SupabaseService.instance.fetchUserProfile(uid);
      if (mounted) {
        setState(() {
          _isPremium = profile['is_premium'] as bool? ?? false;
        });
      }
    } catch (e) {
      // fail quietly but log and keep UI responsive
      if (mounted) {
        setState(() => _isPremium = false);
        // optional: surface a small non-blocking hint
        // ScaffoldMessenger.of(context).showSnackBar(...);
      }
    }
  }

  Future<void> _fetchLoveSectionData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final past = await SupabaseService.instance.fetchPastTcaWinners();
      final active = await SupabaseService.instance.fetchActiveTcaCycle();

      List<Map<String, dynamic>> nominees = [];
      if (active != null && active['id'] != null) {
        nominees = await SupabaseService.instance.fetchTcaNominees(
          active['id'],
        );
      }

      if (!mounted) return;
      setState(() {
        _pastWinners = past;
        _activeCycle = active;
        _nominees = nominees;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching TCA data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVote(String nomineeUsername) async {
    // Guard: premium only
    if (!_isPremium) {
      // Show upgrade CTA with action
      final upgrade = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Premium required'),
          content: const Text(
            'Voting is a premium feature. Upgrade to participate.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Maybe later'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Upgrade'),
            ),
          ],
        ),
      );

      if (upgrade == true) {
        _openUpgrade();
      }
      return;
    }

    if (_activeCycle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active voting cycle.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    // Confirm vote
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Your Vote'),
        content: Text(
          'Are you sure you want to vote for $nomineeUsername? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      await SupabaseService.instance.castTcaVote(
        _activeCycle!['id'],
        nomineeUsername,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully voted for $nomineeUsername!'),
          backgroundColor: Colors.green,
        ),
      );

      // refresh the data so vote counts update
      await _fetchLoveSectionData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error casting vote: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openUpgrade() {
    // Placeholder upgrade flow.
    // Replace with your real navigation to purchase / subscription page.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Upgrade to Premium')),
          body: const Center(child: Text('Upgrade flow goes here')),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            // 1. Title text without Expanded
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _pageTitles[_currentPage],
                key: ValueKey(_currentPage),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
            ),
            // 2. Add a Spacer to push everything else to the right
            const Spacer(),
            // 3. The rest of the widgets remain the same
            Row(
              children: List.generate(
                _pageTitles.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 10 : 6,
                  height: _currentPage == i ? 10 : 6,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? Colors.cyanAccent
                        : Colors.white24,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: () => setState(() => _showWriteUp = !_showWriteUp),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              )
            else
              Column(
                children: [
                  // header (NO premium chip)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            color: Colors.white10,
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              children: <TextSpan>[
                                const TextSpan(
                                  text: 'The Charles Award (TCA) ',
                                  style: TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      'is an initiative from the founder that allows anyone using the SWC app to cash out. It\'s that simple. So show some love by participating in The Charles Award Challenges. Check the "i" button in the top right corner for details on how to participate',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // PageView (swipe to change pages)
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      children: [
                        _buildElectionTab(),
                        const Center(
                          child: Text(
                            'Achievements coming soon.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const Center(
                          child: Text(
                            'Elders’ Suggestions coming soon.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            if (_showWriteUp) _buildWriteUpOverlay(),
          ],
        ),
      ),

      // Bottom big vote button — visible only on Election page (page 0)
      bottomNavigationBar: _currentPage == 0
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: Colors.black,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      // if not premium, show upgrade CTA (same idea as earlier)
                      if (!_isPremium) {
                        final upgrade = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Premium required'),
                            content: const Text(
                              'Voting is a premium feature. Upgrade to participate.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Maybe later'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Upgrade'),
                              ),
                            ],
                          ),
                        );
                        if (upgrade == true) _openUpgrade();
                        return;
                      }

                      // If voting period is closed, do nothing (button shows closed)
                      if (!_isVotingPeriodActive()) return;

                      // If a nominee is already selected, vote for it directly
                      if (_selectedNomineeIndex != null &&
                          _nominees.isNotEmpty) {
                        final username =
                            _nominees[_selectedNomineeIndex!]['username']
                                ?.toString() ??
                            '';
                        if (username.isNotEmpty) {
                          await _handleVote(username);
                        }
                        return;
                      }

                      // No selection: show nominee picker dialog (simple list)
                      final picked = await _showNomineePicker();
                      if (picked != null) {
                        await _handleVote(picked);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_isPremium && _isVotingPeriodActive())
                          ? Colors.redAccent
                          : Colors.redAccent.withOpacity(0.28),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_isPremium) const Icon(Icons.lock, size: 20),
                        if (!_isPremium) const SizedBox(width: 8),
                        Text(
                          !_isVotingPeriodActive()
                              ? 'Voting closed'
                              : (_selectedNomineeIndex == null
                                    ? 'Select a nominee'
                                    : 'VOTE — ${_nominees[_selectedNomineeIndex!]['username'] ?? ''}'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildElectionTab() {
    return RefreshIndicator(
      onRefresh: _fetchLoveSectionData,
      color: Colors.cyanAccent,
      backgroundColor: Colors.black,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Past winners
          const Text(
            'Past Winners',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (_pastWinners.isEmpty)
            const Text(
              'No past winners yet.',
              style: TextStyle(color: Colors.white70),
            )
          else
            ..._pastWinners.map(
              (w) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white10,
                      child: Text(
                        (w['winner_username'] ?? '?').toString().isNotEmpty
                            ? (w['winner_username'][0] as String).toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${w['cycle_id'] ?? 'Cycle'} — ${w['winner_username']} (Prize: ${w['prize_amount'] ?? '—'})',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 18),
          const Divider(color: Colors.white24, height: 12),
          const SizedBox(height: 8),

          // Current nominees header
          const Text(
            'Current Nominees',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),

          if (_nominees.isEmpty)
            Center(
              child: Column(
                children: const [
                  SizedBox(height: 20),
                  Icon(
                    Icons.how_to_vote_outlined,
                    size: 48,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No active voting cycle at the moment.',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_nominees.length, (index) {
              final n = _nominees[index];
              final username = n['username']?.toString() ?? 'Unknown';
              final bio = n['bio']?.toString();
              final votes = n['votes'] ?? 0;
              final selected = _selectedNomineeIndex == index;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedNomineeIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: Colors.cyanAccent, width: 2)
                          : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white12,
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: bio != null
                          ? Text(
                              bio,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite,
                              size: 14,
                              color: Colors.cyanAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              votes.toString(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Future<String?> _showNomineePicker() async {
    if (_nominees.isEmpty) return null;
    return showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose nominee to vote for'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _nominees.length,
              itemBuilder: (context, i) {
                final name = _nominees[i]['username']?.toString() ?? 'Unknown';
                return ListTile(
                  title: Text(name),
                  onTap: () => Navigator.of(context).pop(name),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  bool _isVotingPeriodActive() {
    if (_activeCycle == null) return false;
    final flag = _activeCycle!['is_voting'] ?? _activeCycle!['voting_active'];
    if (flag is bool) return flag;
    // fallback: assume activeCycle means voting allowed
    return true;
  }

  Widget _buildWriteUpOverlay() {
    // Helper widget for consistent rule point styling
    Widget buildRulePoint(String text) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 4.0, right: 8.0),
              child: Icon(Icons.circle, size: 6, color: Colors.cyanAccent),
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _showWriteUp = false),
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              width: MediaQuery.of(context).size.width * 0.86,
              padding: const EdgeInsets.all(20),
              color: Colors.white10,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'The Charles Award',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Current total prize pool: _____________',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    buildRulePoint(
                      'Once a month, a TCA post will be uploaded on all our social media official handles @theswcapp with the caption "#tca".',
                    ),
                    buildRulePoint(
                      'All users (free and plus) can participate by commenting their username in the comment section of that post. You can comment your username or another user\'s username as much as you want.',
                    ),
                    buildRulePoint(
                      'After a week, the "swcaiagent" scrapes all usernames from the comments of the TCA posts and collates the results to nominate users. The most commented username will always be amongst the list of nominees together with other usernames randomly selected by the "swcaiagent".',
                    ),
                    buildRulePoint(
                      'Plus users are five (5) times more likely to get nominated than free users and the number of nominees and winners grows as the plus user number grows.',
                    ),
                    buildRulePoint(
                      'The nominees are given a Charles Award Challenge (CAC) to perform on their social media accounts and whiles they do the challenge, voting will take place simultaneously on the app.',
                    ),
                    buildRulePoint(
                      'The challenges are not compulsory but serve as entertainment for the Charles community and a ticket to convince other plus users to vote for you. All participating nominees are called to be as creative and entertaining as possible.',
                    ),
                    buildRulePoint(
                      'Note that only plus users are allowed to vote.',
                    ),
                    buildRulePoint(
                      'After another week, voting ends on the app and the winner(s) are rewarded with the cash from the current prize pool sent to their USDT wallet set in their profile section.',
                    ),
                    buildRulePoint(
                      'This cycle repeats once every month. Happy Challenge!!',
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Tap anywhere to close',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
