import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/limits.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/models/app_user.dart';
import '../../data/models/slot.dart';
import '../../data/repositories/consultation_repository.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/slot_repository.dart';
import '../auth/auth_provider.dart';
import '../consultations/consultation_notes_screen.dart';
import 'today_controller.dart';

class TodayTimelineScreen extends StatefulWidget {
  const TodayTimelineScreen({super.key, required this.onOpenSchedule});

  /// Switches the bottom navigation to the Schedule tab.
  final VoidCallback onOpenSchedule;

  @override
  State<TodayTimelineScreen> createState() => _TodayTimelineScreenState();
}

class _TodayTimelineScreenState extends State<TodayTimelineScreen> {
  late final AppUser _user;
  late final TodayController _c;

  @override
  void initState() {
    super.initState();
    _user = context.read<AuthProvider>().profile!;
    _c = TodayController(
      user: _user,
      groupRepo: context.read<GroupRepository>(),
      slotRepo: context.read<SlotRepository>(),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _openConsultation(Slot slot) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final repo = context.read<ConsultationRepository>();
    if (await repo.exists(slot.id)) {
      if (!mounted) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => ConsultationScreen(consultationId: slot.id),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Notes will appear here after your adviser starts this consultation.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  user: _user,
                  c: _c,
                  onOpenSchedule: widget.onOpenSchedule,
                  onOpenConsultation: _openConsultation,
                ),
              ),
              if (_c.failed)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    message:
                    'Could not load your schedule. Check your connection.',
                  ),
                )
              else if (_c.loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: LoadingView(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(_body()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _body() {
    final bookings = _c.upcomingBookings;
    final text = Theme.of(context).textTheme;
    final isAdviser = _c.isAdviser;

    final groupsValue = isAdviser
        ? '${_c.groups.length}/${Limits.maxAdviserGroups}'
        : '${_c.groups.length}';

    return [
      Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.groups_rounded,
              value: groupsValue,
              label: 'Groups',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.event_available_rounded,
              value: '${bookings.length}',
              label: 'Booked',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.schedule_rounded,
              value: '${_c.openSlotCount}',
              label: isAdviser ? 'Open slots' : 'To book',
            ),
          ),
        ],
      ),
      if (_c.hasGroupAwaitingAdviser) ...[
        const SizedBox(height: 16),
        const _Notice(
          icon: Icons.hourglass_top_rounded,
          color: AppColors.amber,
          message:
          'A group of yours is waiting for an adviser to accept it. You\'ll see their slots here once they do.',
        ),
      ],
      if (isAdviser && _c.groups.isEmpty) ...[
        const SizedBox(height: 16),
        const _Notice(
          icon: Icons.inbox_rounded,
          color: AppColors.indigo,
          message:
          'No groups yet. Open Groups, then the Requests tab, to accept your first group.',
        ),
      ],
      if (bookings.length > 1) ...[
        const SizedBox(height: 24),
        Text('Coming up', style: text.headlineMedium),
        const SizedBox(height: 12),
        for (final slot in bookings.skip(1).take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _openConsultation(slot),
              borderRadius: BorderRadius.circular(14),
              child: _UpcomingRow(slot: slot, isAdviser: isAdviser),
            ),
          ),
      ],
    ];
  }
}

// ───────────────────────── Header ─────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.c,
    required this.onOpenSchedule,
    required this.onOpenConsultation,
  });

  final AppUser user;
  final TodayController c;
  final VoidCallback onOpenSchedule;
  final ValueChanged<Slot> onOpenConsultation;

  @override
  Widget build(BuildContext context) {
    final firstName =
    user.name.trim().isEmpty ? 'there' : user.name.trim().split(' ').first;
    final role = user.role == UserRole.adviser ? 'Adviser' : 'Student';
    final date = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.indigoDark, AppColors.indigo],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormatters.greeting()},',
                      style: AppTextStyles.body.copyWith(color: Colors.white70),
                    ),
                    Text(
                      firstName,
                      style: AppTextStyles.h1.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$role · $date',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              _ProfileMenu(user: user),
            ],
          ),
          const SizedBox(height: 20),
          _HeroCard(
            c: c,
            onOpenSchedule: onOpenSchedule,
            onOpenConsultation: onOpenConsultation,
          ),
        ],
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final initial =
    user.name.trim().isEmpty ? '?' : user.name.trim()[0].toUpperCase();

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 48),
      onSelected: (v) {
        if (v == 'out') context.read<AuthProvider>().signOut();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: AppTextStyles.title.copyWith(fontSize: 14)),
              Text(user.email, style: AppTextStyles.caption),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'out',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18),
              SizedBox(width: 10),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.ink,
        child: Text(
          initial,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
    );
  }
}

// ───────────────────────── Hero card ─────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.c,
    required this.onOpenSchedule,
    required this.onOpenConsultation,
  });

  final TodayController c;
  final VoidCallback onOpenSchedule;
  final ValueChanged<Slot> onOpenConsultation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: c.loading
            ? const SizedBox(
          height: 90,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.indigo),
          ),
        )
            : (c.upcomingBookings.isEmpty
            ? Padding(
          padding: const EdgeInsets.all(20),
          child: _emptyHero(),
        )
            : InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onOpenConsultation(c.upcomingBookings.first),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _nextHero(c.upcomingBookings.first),
          ),
        )),
      ),
    );
  }

  Widget _nextHero(Slot next) {
    final who = c.isAdviser
        ? '${next.bookedGroupName} (booked by ${next.bookedByName})'
        : '${next.bookedGroupName} · with ${next.adviserName}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'NEXT CONSULTATION',
              style: AppTextStyles.caption.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                DateFormatters.until(next.start, next.durationMins),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          DateFormatters.range(next.start, next.durationMins),
          style: AppTextStyles.h1.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormatters.dayHeader(next.start),
          style: AppTextStyles.body.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.groups_rounded, size: 18, color: AppColors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                who,
                style: AppTextStyles.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _emptyHero() {
    final isAdviser = c.isAdviser;
    final noGroups = !isAdviser && c.groups.isEmpty;
    final waiting = !isAdviser && c.groups.isNotEmpty && !c.hasAnyAdviser;

    final String message;
    String? buttonLabel;
    if (isAdviser) {
      message = 'Publish your availability so groups can book you.';
      buttonLabel = 'Add availability';
    } else if (noGroups) {
      message =
      'Create or join a thesis group in the Groups tab to get started.';
    } else if (waiting) {
      message =
      'Once an adviser accepts your group, you can book a consultation.';
    } else {
      message = 'Book a slot with your adviser to get started.';
      buttonLabel = 'Browse slots';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.indigoTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: AppColors.indigo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No consultations scheduled',
                style: AppTextStyles.title,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: AppTextStyles.body.copyWith(color: AppColors.muted),
        ),
        if (buttonLabel != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: onOpenSchedule,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ],
    );
  }
}

// ───────────────────────── Pieces ─────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.indigoTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.indigo),
          ),
          const SizedBox(height: 12),
          Text(value, style: AppTextStyles.h2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.slot, required this.isAdviser});
  final Slot slot;
  final bool isAdviser;

  @override
  Widget build(BuildContext context) {
    final d = slot.start;
    final who = isAdviser
        ? slot.bookedGroupName ?? ''
        : '${slot.bookedGroupName} · ${slot.adviserName}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.indigoTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '${d.day}',
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 20,
                    color: AppColors.indigo,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(d).toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.indigo,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormatters.range(slot.start, slot.durationMins),
                  style: AppTextStyles.title,
                ),
                const SizedBox(height: 2),
                Text(
                  who,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}