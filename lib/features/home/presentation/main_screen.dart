import 'package:flutter/material.dart';
import 'package:studywithcharles/features/study/presentation/study_list_screen.dart';
import 'package:studywithcharles/features/timetable/presentation/timetable_screen.dart';
import 'package:studywithcharles/features/love/presentation/love_screen.dart';
import 'package:studywithcharles/features/pricing/presentation/pricing_screen.dart';
import 'package:studywithcharles/features/profile/presentation/profile_screen.dart';

class MainScreen extends StatefulWidget {
  static const routeName = '/';
  // We add this to accept the starting tab index
  final int? initialPageIndex;

  const MainScreen({super.key, this.initialPageIndex});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // If an initial index is provided, use it. Otherwise, default to 0.
    _currentIndex = widget.initialPageIndex ?? 0;
  }

  static const List<Widget> _tabs = [
    StudyListScreen(),
    TimetableScreen(),
    LoveSectionScreen(),
    PricingScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.white70,
        backgroundColor: Colors.black, // Added for better theme consistency
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Study'),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Timetable',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Love'),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on),
            label: 'Pricing',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
