import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/app_user.dart';
import '../../data/sync/sync_service.dart';
import '../auth/auth_provider.dart';
import '../groups/groups_screen.dart';
import '../milestones/progress_screen.dart';
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
  late final SyncService _sync;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().profile!;
    final auth = context.read<AuthProvider>();
    _index = auth.takeJustJoined() ? 2 : 0;
    final notice = auth.takeNotice();
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(notice)));
        }
      });
    }
    _sync = context.read<SyncService>()..start(user);

    final isAdviser = user.role == UserRole.adviser;
    _pages = [
      TodayTimelineScreen(onOpenSchedule: () => setState(() => _index = 1)),
      isAdviser ? const AdviserAvailabilityScreen() : const BookingScreen(),
      const GroupsScreen(),
      const ProgressScreen(),
    ];
  }

  @override
  void dispose() {
    _sync.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: NavigationBar(
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
            NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag_rounded),
              label: 'Progress',
            ),
          ],
        ),
      ),
    );
  }
}
