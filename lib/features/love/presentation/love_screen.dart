// lib/features/love/presentation/love_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:studywithcharles/shared/services/auth_service.dart';

class LoveSectionScreen extends StatefulWidget {
  const LoveSectionScreen({super.key});

  @override
  State<LoveSectionScreen> createState() => _LoveSectionScreenState();
}

class _LoveSectionScreenState extends State<LoveSectionScreen> {
  bool _showWriteUp = false;
  bool _isPremium = false;

  // dummy data
  final List<Map<String, dynamic>> _pastWinners = [
    {'year': 2022, 'name': 'Alice', 'prize': '\$1,000'},
    {'year': 2023, 'name': 'Bob', 'prize': '\$2,000'},
  ];
  final List<String> _nominees = ['Charles', 'Dana', 'Evan'];
  final List<String> _achievements = [
    'Library build',
    'Scholarship fund',
    'Community workshop',
  ];
  final List<String> _elderProposals = [
    'Solar lamp drive',
    'Free coding camp',
    'Food pantry expansion',
  ];
  final Map<String, bool> _proposalVotes = {};

  @override
  void initState() {
    super.initState();
    _checkPremium();
  }

  void _checkPremium() {
    final user = AuthService.instance.currentUser;
    setState(() {
      _isPremium = user != null && user.email?.endsWith('@premium.com') == true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false, // no back button
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Align(
          alignment: Alignment.centerLeft, // left-aligned
          child: Text(
            'Love Section',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Colors.white, // white text
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => setState(() => _showWriteUp = true),
          ),
        ],
      ),
      body: Stack(
        children: [
          DefaultTabController(
            length: 3,
            child: Column(
              children: [
                // TCA instructions panel
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: Colors.white10,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
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

                // Tab bar
                TabBar(
                  labelColor: Colors.cyanAccent,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.cyanAccent,
                  tabs: const [
                    Tab(text: 'Election'),
                    Tab(text: 'Achievements'),
                    Tab(text: 'Elders’ Suggestions'),
                  ],
                ),

                // Tab views
                Expanded(
                  child: TabBarView(
                    children: [
                      // Election Tab
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Past Winners:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._pastWinners.map(
                              (w) => Text(
                                '${w['year']}: ${w['name']} (${w['prize']})',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                            const Divider(color: Colors.white24),
                            const Text(
                              'Current Nominees:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._nominees.map(
                              (n) => Text(
                                n,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                            const Spacer(),
                            Center(
                              child: ElevatedButton(
                                onPressed: _isPremium
                                    ? () {
                                        // TODO: voting flow
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyanAccent,
                                ),
                                child: Text(
                                  _isPremium ? 'Vote Now' : 'Vote (Premium)',
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Achievements Tab
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: ListView(
                          children: [
                            for (var a in _achievements)
                              ListTile(
                                leading: const Icon(
                                  Icons.check_circle,
                                  color: Colors.cyanAccent,
                                ),
                                title: Text(
                                  a,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Elders’ Suggestions Tab
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: ListView(
                          children: [
                            for (var suggestion in _elderProposals)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 6,
                                    sigmaY: 6,
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    color: Colors.white10,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            suggestion,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            _proposalVotes[suggestion] == true
                                                ? Icons.thumb_up
                                                : Icons.thumb_up_outlined,
                                            color: Colors.cyanAccent,
                                          ),
                                          onPressed: _isPremium
                                              ? () {
                                                  setState(
                                                    () =>
                                                        _proposalVotes[suggestion] =
                                                            true,
                                                  );
                                                }
                                              : null,
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            _proposalVotes[suggestion] == false
                                                ? Icons.thumb_down
                                                : Icons.thumb_down_outlined,
                                            color: Colors.white70,
                                          ),
                                          onPressed: _isPremium
                                              ? () {
                                                  setState(
                                                    () =>
                                                        _proposalVotes[suggestion] =
                                                            false,
                                                  );
                                                }
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Write‑up overlay
          if (_showWriteUp)
            GestureDetector(
              onTap: () => setState(() => _showWriteUp = false),
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        padding: const EdgeInsets.all(24),
                        color: Colors.white10,
                        child: SingleChildScrollView(
                          child: Column(
                            children: const [
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
                                'The Charles Award is our founder’s philanthropic initiative, '
                                'selected by community vote each year to fund one worthy project. '
                                'Nominate, vote, and celebrate our winners—let’s give back to the Charles community together!',
                                style: TextStyle(color: Colors.white70),
                              ),
                              SizedBox(height: 24),
                              Text(
                                'Tap anywhere to close',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
