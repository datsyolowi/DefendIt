class Group {
  const Group({
    required this.id,
    required this.name,
    required this.thesisTitle,
    required this.code,
    required this.memberUids,
    required this.memberNames,
    required this.roster,
    required this.createdAt,
    this.leaderUid,
    this.adviserUid,
    this.adviserName,
  });

  final String id;
  final String name;
  final String thesisTitle;
  final String code;
  final List<String> memberUids; // accounts with access to this group
  final Map<String, String> memberNames; // uid -> display name
  final List<String> roster; // official member names; roster.first = leader
  final int createdAt; // millis since epoch
  final String? leaderUid;
  final String? adviserUid;
  final String? adviserName;

  /// "Ana Cruz (leader), Ben Lim, Carla Reyes"
  String get rosterLabel {
    if (roster.isEmpty) return '';
    return [
      '${roster.first} (leader)',
      ...roster.skip(1),
    ].join(', ');
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'thesisTitle': thesisTitle,
    'code': code,
    'memberUids': memberUids,
    'memberNames': memberNames,
    'roster': roster,
    'createdAt': createdAt,
    'leaderUid': leaderUid,
    'adviserUid': adviserUid,
    'adviserName': adviserName,
  };

  factory Group.fromMap(Map<String, dynamic> m, String id) {
    final uids = List<String>.from(m['memberUids'] ?? const []);
    final names = Map<String, String>.from(
        (m['memberNames'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
            const {});
    final roster = m['roster'] == null
        ? names.values.toList() // older groups created before rosters
        : List<String>.from(m['roster']);

    return Group(
      id: id,
      name: (m['name'] as String?) ?? '',
      thesisTitle: (m['thesisTitle'] as String?) ?? '',
      code: (m['code'] as String?) ?? '',
      memberUids: uids,
      memberNames: names,
      roster: roster,
      createdAt: (m['createdAt'] as int?) ?? 0,
      leaderUid:
      (m['leaderUid'] as String?) ?? (uids.isNotEmpty ? uids.first : null),
      adviserUid: m['adviserUid'] as String?,
      adviserName: m['adviserName'] as String?,
    );
  }
}