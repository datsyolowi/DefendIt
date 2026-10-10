class ActionItem {
  const ActionItem({
    required this.id,
    required this.consultationId,
    required this.groupId,
    required this.groupName,
    required this.adviserUid,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.assignee,
    this.dueAt,
    this.done = false,
    this.doneAt,
  });

  final String id;
  final String consultationId;
  final String groupId;
  final String groupName;
  final String adviserUid;
  final String title;
  final String? assignee; // roster name, null = whole group
  final int? dueAt;
  final bool done;
  final int? doneAt;
  final int createdAt;
  final int updatedAt;

  DateTime? get due =>
      dueAt == null ? null : DateTime.fromMillisecondsSinceEpoch(dueAt!);

  bool get isOverdue =>
      !done && dueAt != null && dueAt! < DateTime.now().millisecondsSinceEpoch;

  /// Firestore shape.
  Map<String, dynamic> toMap() => {
    'consultationId': consultationId,
    'groupId': groupId,
    'groupName': groupName,
    'adviserUid': adviserUid,
    'title': title,
    'assignee': assignee,
    'dueAt': dueAt,
    'done': done,
    'doneAt': doneAt,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory ActionItem.fromMap(Map<String, dynamic> m, String id) => ActionItem(
    id: id,
    consultationId: (m['consultationId'] as String?) ?? '',
    groupId: (m['groupId'] as String?) ?? '',
    groupName: (m['groupName'] as String?) ?? '',
    adviserUid: (m['adviserUid'] as String?) ?? '',
    title: (m['title'] as String?) ?? '',
    assignee: m['assignee'] as String?,
    dueAt: (m['dueAt'] as num?)?.toInt(),
    done: m['done'] == true || m['done'] == 1,
    doneAt: (m['doneAt'] as num?)?.toInt(),
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
    updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
  );

  /// sqflite row shape (bool stored as 0/1).
  Map<String, Object?> toRow() =>
      {...toMap(), 'id': id, 'done': done ? 1 : 0};

  factory ActionItem.fromRow(Map<String, Object?> r) =>
      ActionItem.fromMap(Map<String, dynamic>.from(r), r['id'] as String);
}