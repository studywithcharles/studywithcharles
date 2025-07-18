// lib/features/home/presentation/main_screen.dart

import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  static const routeName = '/study';
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final _tabs = [
    const Center(child: Text('Study Screen')),
    const Center(child: Text('Timetable Screen')),
    const Center(child: Text('Love Section')),
    const Center(child: Text('Pricing')),
    const Center(child: Text('Profile')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
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
