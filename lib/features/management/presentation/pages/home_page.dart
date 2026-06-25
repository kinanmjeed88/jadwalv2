import 'package:flutter/material.dart';
import 'management_page.dart';
import '../../../timetable/presentation/pages/timetable_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const TimetablePage(),
    const ManagementPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.table_chart),
            label: 'الجدول',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts),
            label: 'الإدارة',
          ),
        ],
      ),
    );
  }
}
