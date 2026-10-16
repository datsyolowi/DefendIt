import '../local/app_database.dart';
import '../models/app_user.dart';
import '../models/milestone.dart';
import '../models/milestone_task.dart';

enum AttentionKind {
  milestoneRevision,
  titlePolish,
  milestoneReview,
  titleReview,
  milestoneOverdue,
  taskOverdue,
  actionOverdue,
  readyToSubmit,
}

/// Where tapping an entry should go.
class AttentionTarget {
  const AttentionTarget({
    required this.groupId,
    this.milestoneId,
    this.consultationId,
  });
  final String groupId;
  final String? milestoneId;
  final String? consultationId;
}

class AttentionEntry {
  const AttentionEntry({
    required this.kind,
    required this.count,
    required this.target,
  });
  final AttentionKind kind;
  final int count;
  final AttentionTarget target;
}

/// Builds the "Needs attention" list from the local database only, so it
/// works offline. Entries are ordered by urgency for each role.
class AttentionRepository {
  AttentionRepository(this._db);
  final AppDatabase _db;

  Stream<List<AttentionEntry>> watch(AppUser user) =>
      _db.watch<List<AttentionEntry>>(() => _load(user));

  Future<List<AttentionEntry>> _load(AppUser user) async {
    final db = await _db.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    final isAdviser = user.role == UserRole.adviser;

    final milestones = (await db.query('milestones',
        orderBy: 'groupId ASC, position ASC'))
        .map(Milestone.fromRow)
        .toList();

    final countRows = await db.rawQuery('''
      SELECT milestoneId, COUNT(*) AS total, SUM(done) AS done
      FROM milestone_tasks GROUP BY milestoneId''');
    final counts = {
      for (final r in countRows)
        r['milestoneId'] as String: TaskCount(
          done: (r['done'] as num?)?.toInt() ?? 0,
          total: (r['total'] as num).toInt(),
        ),
    };

    List<Milestone> withStatus(MilestoneStatus s) =>
        milestones.where((m) => m.status == s).toList();

    final revision = withStatus(MilestoneStatus.needsRevision);
    final review = withStatus(MilestoneStatus.forReview);
    final ready = milestones.where((m) {
      final c = counts[m.id];
      return m.status == MilestoneStatus.inProgress &&
          c != null &&
          c.total > 0 &&
          c.done == c.total;
    }).toList();
    final overdueMilestones = milestones
        .where((m) =>
    m.dueAt != null &&
        m.dueAt! < now &&
        m.status != MilestoneStatus.approved)
        .toList();

    final titles = await db.query('title_ideas',
        where: 'status = ?',
        whereArgs: [isAdviser ? 'pending' : 'needsPolish'],
        orderBy: 'updatedAt ASC');

    final overdueTasks = await db.rawQuery('''
      SELECT t.groupId AS groupId, t.milestoneId AS milestoneId
      FROM milestone_tasks t JOIN milestones m ON m.id = t.milestoneId
      WHERE t.done = 0 AND t.dueAt IS NOT NULL AND t.dueAt < ?
        AND m.status != 'approved'
      ORDER BY t.dueAt ASC''', [now]);

    final overdueItems = await db.rawQuery('''
      SELECT groupId, consultationId FROM action_items
      WHERE done = 0 AND dueAt IS NOT NULL AND dueAt < ?
      ORDER BY dueAt ASC''', [now]);

    AttentionEntry? fromMilestones(AttentionKind kind, List<Milestone> list) =>
        list.isEmpty
            ? null
            : AttentionEntry(
          kind: kind,
          count: list.length,
          target: AttentionTarget(
              groupId: list.first.groupId, milestoneId: list.first.id),
        );

    final titleEntry = titles.isEmpty
        ? null
        : AttentionEntry(
      kind:
      isAdviser ? AttentionKind.titleReview : AttentionKind.titlePolish,
      count: titles.length,
      target: AttentionTarget(groupId: titles.first['groupId'] as String),
    );

    final taskEntry = overdueTasks.isEmpty
        ? null
        : AttentionEntry(
      kind: AttentionKind.taskOverdue,
      count: overdueTasks.length,
      target: AttentionTarget(
        groupId: overdueTasks.first['groupId'] as String,
        milestoneId: overdueTasks.first['milestoneId'] as String,
      ),
    );

    final itemEntry = overdueItems.isEmpty
        ? null
        : AttentionEntry(
      kind: AttentionKind.actionOverdue,
      count: overdueItems.length,
      target: AttentionTarget(
        groupId: overdueItems.first['groupId'] as String,
        consultationId: overdueItems.first['consultationId'] as String,
      ),
    );

    final entries = isAdviser
        ? [
      fromMilestones(AttentionKind.milestoneReview, review),
      titleEntry,
      fromMilestones(AttentionKind.milestoneOverdue, overdueMilestones),
      taskEntry,
      itemEntry,
    ]
        : [
      fromMilestones(AttentionKind.milestoneRevision, revision),
      titleEntry,
      fromMilestones(AttentionKind.milestoneOverdue, overdueMilestones),
      taskEntry,
      itemEntry,
      fromMilestones(AttentionKind.readyToSubmit, ready),
    ];

    return entries.whereType<AttentionEntry>().toList();
  }
}