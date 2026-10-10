import 'dart:convert';

class Consultation {
  const Consultation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.adviserUid,
    required this.adviserName,
    required this.startsAt,
    required this.durationMins,
    required this.roster,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id; // same id as the booked slot
  final String groupId;
  final String groupName;
  final String adviserUid;
  final String adviserName;
  final int startsAt;
  final int durationMins;
  final List<String> roster; // copied from the group when created
  final String notes;
  final int createdAt;
  final int updatedAt;

  DateTime get start => DateTime.fromMillisecondsSinceEpoch(startsAt);

  /// Firestore shape.
  Map<String, dynamic> toMap() => {
    'groupId': groupId,
    'groupName': groupName,
    'adviserUid': adviserUid,
    'adviserName': adviserName,
    'startsAt': startsAt,
    'durationMins': durationMins,
    'roster': roster,
    'notes': notes,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory Consultation.fromMap(Map<String, dynamic> m, String id) =>
      Consultation(
        id: id,
        groupId: (m['groupId'] as String?) ?? '',
        groupName: (m['groupName'] as String?) ?? '',
        adviserUid: (m['adviserUid'] as String?) ?? '',
        adviserName: (m['adviserName'] as String?) ?? '',
        startsAt: (m['startsAt'] as num?)?.toInt() ?? 0,
        durationMins: (m['durationMins'] as num?)?.toInt() ?? 30,
        roster: List<String>.from(m['roster'] ?? const []),
        notes: (m['notes'] as String?) ?? '',
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
      );

  /// sqflite row shape (roster stored as JSON text).
  Map<String, Object?> toRow() =>
      {...toMap(), 'id': id, 'roster': jsonEncode(roster)};

  factory Consultation.fromRow(Map<String, Object?> r) {
    final m = Map<String, dynamic>.from(r);
    m['roster'] = jsonDecode(r['roster'] as String);
    return Consultation.fromMap(m, r['id'] as String);
  }
}