enum MilestoneStatus {
  notStarted,
  inProgress,
  forReview,
  needsRevision,
  approved;

  static MilestoneStatus fromName(String? name) => values.firstWhere(
        (s) => s.name == name,
    orElse: () => MilestoneStatus.notStarted,
  );

  String get label {
    switch (this) {
      case MilestoneStatus.notStarted:
        return 'Not started';
      case MilestoneStatus.inProgress:
        return 'In progress';
      case MilestoneStatus.forReview:
        return 'For review';
      case MilestoneStatus.needsRevision:
        return 'Needs revision';
      case MilestoneStatus.approved:
        return 'Approved';
    }
  }

  /// Moves a group member may make from this status.
  List<MilestoneStatus> get studentNext {
    switch (this) {
      case MilestoneStatus.notStarted:
        return const [MilestoneStatus.inProgress];
      case MilestoneStatus.inProgress:
        return const [MilestoneStatus.forReview];
      case MilestoneStatus.forReview:
        return const [MilestoneStatus.inProgress]; // withdraw
      case MilestoneStatus.needsRevision:
        return const [MilestoneStatus.inProgress, MilestoneStatus.forReview];
      case MilestoneStatus.approved:
        return const [];
    }
  }

  /// Moves the group's adviser may make from this status.
  List<MilestoneStatus> get adviserNext => this == MilestoneStatus.forReview
      ? const [MilestoneStatus.approved, MilestoneStatus.needsRevision]
      : const [];

  /// Students may add, edit, and tick tasks only in these statuses.
  bool get allowsTaskEdits =>
      this == MilestoneStatus.notStarted ||
          this == MilestoneStatus.inProgress ||
          this == MilestoneStatus.needsRevision;
}

class Milestone {
  const Milestone({
    required this.id,
    required this.groupId,
    required this.slug,
    required this.title,
    required this.position,
    required this.status,
    required this.updatedAt,
    this.dueAt,
    this.comment,
    this.updatedByName,
  });

  final String id; // '<groupId>_<slug>', unique across groups
  final String groupId;
  final String slug;
  final String title;
  final int position;
  final MilestoneStatus status;
  final int updatedAt;
  final int? dueAt;
  final String? comment; // adviser's feedback
  final String? updatedByName;

  DateTime? get due =>
      dueAt == null ? null : DateTime.fromMillisecondsSinceEpoch(dueAt!);

  bool get isOverdue =>
      status != MilestoneStatus.approved &&
          dueAt != null &&
          dueAt! < DateTime.now().millisecondsSinceEpoch;

  static const _defaults = [
    ('title_approval', 'Title approval'),
    ('chapter_1', 'Chapter 1: Introduction'),
    ('chapter_2', 'Chapter 2: Review of Related Literature'),
    ('chapter_3', 'Chapter 3: Methodology'),
    ('proposal_defense', 'Proposal defense'),
    ('final_defense', 'Final defense'),
  ];

  /// The standard milestone list every group starts with.
  static List<Milestone> defaults(String groupId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      for (var i = 0; i < _defaults.length; i++)
        Milestone(
          id: '${groupId}_${_defaults[i].$1}',
          groupId: groupId,
          slug: _defaults[i].$1,
          title: _defaults[i].$2,
          position: i + 1,
          status: MilestoneStatus.notStarted,
          updatedAt: now,
        ),
    ];
  }

  Map<String, dynamic> toMap() => {
    'groupId': groupId,
    'slug': slug,
    'title': title,
    'position': position,
    'status': status.name,
    'dueAt': dueAt,
    'comment': comment,
    'updatedByName': updatedByName,
    'updatedAt': updatedAt,
  };

  factory Milestone.fromMap(Map<String, dynamic> m, String id) => Milestone(
    id: id,
    groupId: (m['groupId'] as String?) ?? '',
    slug: (m['slug'] as String?) ?? '',
    title: (m['title'] as String?) ?? '',
    position: (m['position'] as num?)?.toInt() ?? 0,
    status: MilestoneStatus.fromName(m['status'] as String?),
    dueAt: (m['dueAt'] as num?)?.toInt(),
    comment: m['comment'] as String?,
    updatedByName: m['updatedByName'] as String?,
    updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
  );

  /// sqflite row shape (same fields as Firestore, plus the id).
  Map<String, Object?> toRow() => {...toMap(), 'id': id};

  factory Milestone.fromRow(Map<String, Object?> r) =>
      Milestone.fromMap(Map<String, dynamic>.from(r), r['id'] as String);
}