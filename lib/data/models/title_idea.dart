enum TitleStatus {
  pending,
  approved,
  needsPolish,
  rejected;

  static TitleStatus fromName(String? name) => values.firstWhere(
        (s) => s.name == name,
    orElse: () => TitleStatus.pending,
  );

  String get label {
    switch (this) {
      case TitleStatus.pending:
        return 'Pending review';
      case TitleStatus.approved:
        return 'Approved';
      case TitleStatus.needsPolish:
        return 'Needs polish';
      case TitleStatus.rejected:
        return 'Rejected';
    }
  }
}

class TitleIdea {
  const TitleIdea({
    required this.id,
    required this.groupId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    this.comment,
    this.reviewedByName,
    this.reviewedAt,
  });

  final String id;
  final String groupId;
  final String title;
  final String description;
  final TitleStatus status;
  final String createdByUid;
  final String createdByName;
  final int createdAt;
  final int updatedAt;
  final String? comment; // adviser's comment
  final String? reviewedByName;
  final int? reviewedAt;

  bool get isReviewed => status != TitleStatus.pending;

  /// Students can revise ideas that are waiting or need polish.
  bool get studentCanEdit =>
      status == TitleStatus.pending || status == TitleStatus.needsPolish;

  bool get studentCanDelete => status != TitleStatus.approved;

  Map<String, dynamic> toMap() => {
    'groupId': groupId,
    'title': title,
    'description': description,
    'status': status.name,
    'createdByUid': createdByUid,
    'createdByName': createdByName,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'comment': comment,
    'reviewedByName': reviewedByName,
    'reviewedAt': reviewedAt,
  };

  factory TitleIdea.fromMap(Map<String, dynamic> m, String id) => TitleIdea(
    id: id,
    groupId: (m['groupId'] as String?) ?? '',
    title: (m['title'] as String?) ?? '',
    description: (m['description'] as String?) ?? '',
    status: TitleStatus.fromName(m['status'] as String?),
    createdByUid: (m['createdByUid'] as String?) ?? '',
    createdByName: (m['createdByName'] as String?) ?? '',
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
    updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
    comment: m['comment'] as String?,
    reviewedByName: m['reviewedByName'] as String?,
    reviewedAt: (m['reviewedAt'] as num?)?.toInt(),
  );
}