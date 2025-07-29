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

  // State variables to hold live data from Supabase
  Map<String, dynamic>? _activeCycle;
  List<Map<String, dynamic>> _pastWinners = [];
  List<Map<String, dynamic>> _nominees = [];
  // We will add elder proposals later

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _fetchLoveSectionData();
  }

  // We will replace this with a real check from your database later.
  void _checkPremiumStatus() {
    final user = AuthService.instance.currentUser;
    setState(() {
      _isPremium = user != null && user.email!.endsWith('@premium.com');
    });
  }

  Future<void> _fetchLoveSectionData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _pastWinners = await SupabaseService.instance.fetchPastTcaWinners();
      _activeCycle = await SupabaseService.instance.fetchActiveTcaCycle();

      if (_activeCycle != null) {
        _nominees = await SupabaseService.instance.fetchTcaNominees(
          _activeCycle!['id'],
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching TCA data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleVote(String nomineeUsername) async {
    if (!_isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voting is a premium feature.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    if (_activeCycle == null) return;

    // Guard the context before the async gap
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Your Vote'),
        content: Text(
          'Are you sure you want to vote for $nomineeUsername? This cannot be undone.',
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

    // Guard the context after the async gap
    if (!mounted) return;

    if (confirm == true) {
      try {
        await SupabaseService.instance.castTcaVote(
          _activeCycle!['id'],
          nomineeUsername,
        );

        // Guard the context again after the final await
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully voted for $nomineeUsername!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error casting vote: You may have already voted in this cycle.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Love Section',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => setState(() => _showWriteUp = !_showWriteUp),
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.cyanAccent),
                )
              : DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              color: Colors.white10,
                              padding: const EdgeInsets.all(16),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'The Charles Award',
                                    style: TextStyle(
                                      color: Colors.cyanAccent,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Participate by nominating, voting, and celebrating our community heroes.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const TabBar(
                        labelColor: Colors.cyanAccent,
                        unselectedLabelColor: Colors.white70,
                        indicatorColor: Colors.cyanAccent,
                        tabs: [
                          Tab(text: 'Election'),
                          Tab(text: 'Achievements'),
                          Tab(text: 'Elders’ Suggestions'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
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
                ),
          if (_showWriteUp) _buildWriteUpOverlay(),
        ],
      ),
    );
  }

  Widget _buildElectionTab() {
    return RefreshIndicator(
      onRefresh: _fetchLoveSectionData,
      color: Colors.cyanAccent,
      backgroundColor: Colors.black,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Past Winners:',
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
              (w) => Text(
                '${w['cycle_id'] ?? 'Previous Cycle'}: ${w['winner_username']} (Prize: ${w['prize_amount']})',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          const Divider(color: Colors.white24, height: 32),
          const Text(
            'Current Nominees:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (_nominees.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: Center(
                child: Text(
                  'No active voting cycle at the moment.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            )
          else
            ..._nominees.map(
              (n) => Card(
                color: Colors.white10,
                child: ListTile(
                  title: Text(
                    n['username'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _handleVote(n['username']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPremium
                          ? Colors.cyanAccent
                          : Colors.grey[700],
                      foregroundColor: Colors.black,
                    ),
                    child: Text(_isPremium ? 'Vote' : 'Premium'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWriteUpOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showWriteUp = false),
      child: Container(
        // FIXED: Replaced deprecated 'withOpacity'
        color: Colors.black54,
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                color: Colors.white10,
                child: const SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'About The Charles Award',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'The Charles Award is our founder’s philanthropic initiative, selected by community vote each year to fund one worthy project. Nominate, vote, and celebrate our winners—let’s give back to the Charles community together!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, height: 1.5),
                      ),
                      SizedBox(height: 24),
                      Text(
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
      ),
    );
  }
}
