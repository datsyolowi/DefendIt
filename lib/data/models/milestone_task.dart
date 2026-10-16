class MilestoneTask {
  const MilestoneTask({
    required this.id,
    required this.groupId,
    required this.milestoneId,
    required this.title,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    this.assignee,
    this.dueAt,
    this.done = false,
    this.doneAt,
    this.doneByName,
  });

  final String id;
  final String groupId;
  final String milestoneId;
  final String title;
  final String? assignee; // roster name; null = whole group
  final int? dueAt;
  final bool done;
  final int? doneAt;
  final String? doneByName;
  final String createdByName;
  final int createdAt;
  final int updatedAt;

  DateTime? get due =>
      dueAt == null ? null : DateTime.fromMillisecondsSinceEpoch(dueAt!);

  bool get isOverdue =>
      !done && dueAt != null && dueAt! < DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
    'groupId': groupId,
    'milestoneId': milestoneId,
    'title': title,
    'assignee': assignee,
    'dueAt': dueAt,
    'done': done,
    'doneAt': doneAt,
    'doneByName': doneByName,
    'createdByName': createdByName,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory MilestoneTask.fromMap(Map<String, dynamic> m, String id) =>
      MilestoneTask(
        id: id,
        groupId: (m['groupId'] as String?) ?? '',
        milestoneId: (m['milestoneId'] as String?) ?? '',
        title: (m['title'] as String?) ?? '',
        assignee: m['assignee'] as String?,
        dueAt: (m['dueAt'] as num?)?.toInt(),
        done: m['done'] == true || m['done'] == 1,
        doneAt: (m['doneAt'] as num?)?.toInt(),
        doneByName: m['doneByName'] as String?,
        createdByName: (m['createdByName'] as String?) ?? '',
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
      );

  /// sqflite row shape (bool stored as 0/1).
  Map<String, Object?> toRow() =>
      {...toMap(), 'id': id, 'done': done ? 1 : 0};

  factory MilestoneTask.fromRow(Map<String, Object?> r) =>
      MilestoneTask.fromMap(Map<String, dynamic>.from(r), r['id'] as String);
}

class TaskCount {
  const TaskCount({required this.done, required this.total});
  final int done;
  final int total;
  double get ratio => total == 0 ? 0 : done / total;
}