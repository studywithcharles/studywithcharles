// lib/features/home/presentation/main_screen.dart

import 'package:flutter/material.dart';
import 'package:studywithcharles/features/study/presentation/study_list_screen.dart';

class MainScreen extends StatefulWidget {
  static const routeName = '/';
  const MainScreen({Key? key}) : super(key: key);

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Keep all five tabs; replace Centers with your real screens as you build them
  static const List<Widget> _tabs = [
    StudyListScreen(),
    Center(child: Text('Timetable Screen')),
    Center(child: Text('Love Section')),
    Center(child: Text('Pricing')),
    Center(child: Text('Profile')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We let StudyListScreen draw its own AppBar for the Study tab
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.white70,
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
