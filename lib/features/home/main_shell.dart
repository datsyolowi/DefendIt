import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/app_user.dart';
import '../auth/auth_provider.dart';
import '../groups/groups_screen.dart';
import '../slots/adviser_availability_screen.dart';
import '../slots/booking_screen.dart';
import 'today_timeline_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    final isAdviser =
        context.read<AuthProvider>().profile?.role == UserRole.adviser;
    _pages = [
      const TodayTimelineScreen(),
      isAdviser ? const AdviserAvailabilityScreen() : const BookingScreen(),
      const GroupsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event_rounded),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Groups',
          ),
        ],
      ),
    );
  }
}