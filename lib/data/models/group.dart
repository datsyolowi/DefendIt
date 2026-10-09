class Group {
  const Group({
    required this.id,
    required this.name,
    required this.thesisTitle,
    required this.code,
    required this.memberUids,
    required this.memberNames,
    required this.createdAt,
    this.adviserUid,
    this.adviserName,
  });

  final String id;
  final String name;
  final String thesisTitle;
  final String code;
  final List<String> memberUids;
  final Map<String, String> memberNames; // uid -> display name
  final int createdAt; // millis since epoch (easy to store in sqflite later)
  final String? adviserUid;
  final String? adviserName;

  Map<String, dynamic> toMap() => {
    'name': name,
    'thesisTitle': thesisTitle,
    'code': code,
    'memberUids': memberUids,
    'memberNames': memberNames,
    'createdAt': createdAt,
    'adviserUid': adviserUid,
    'adviserName': adviserName,
  };

  factory Group.fromMap(Map<String, dynamic> m, String id) => Group(
    id: id,
    name: (m['name'] as String?) ?? '',
    thesisTitle: (m['thesisTitle'] as String?) ?? '',
    code: (m['code'] as String?) ?? '',
    memberUids: List<String>.from(m['memberUids'] ?? const []),
    memberNames: Map<String, String>.from(
        (m['memberNames'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
            const {}),
    createdAt: (m['createdAt'] as int?) ?? 0,
    adviserUid: m['adviserUid'] as String?,
    adviserName: m['adviserName'] as String?,
  );
}