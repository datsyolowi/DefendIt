enum SlotStatus {
  open,
  booked;

  static SlotStatus fromName(String? name) => values.firstWhere(
        (s) => s.name == name,
    orElse: () => SlotStatus.open,
  );
}

class Slot {
  const Slot({
    required this.id,
    required this.adviserUid,
    required this.adviserName,
    required this.startsAt,
    required this.durationMins,
    required this.status,
    required this.createdAt,
    this.bookedGroupId,
    this.bookedGroupName,
    this.bookedByUid,
    this.bookedByName,
  });

  final String id;
  final String adviserUid;
  final String adviserName;
  final int startsAt; // millis since epoch
  final int durationMins;
  final SlotStatus status;
  final int createdAt;
  final String? bookedGroupId;
  final String? bookedGroupName;
  final String? bookedByUid;
  final String? bookedByName;

  DateTime get start => DateTime.fromMillisecondsSinceEpoch(startsAt);
  DateTime get end => start.add(Duration(minutes: durationMins));
  bool get isBooked => status == SlotStatus.booked;

  /// Still relevant: has not finished yet.
  bool get isUpcoming => end.isAfter(DateTime.now());

  Map<String, dynamic> toMap() => {
    'adviserUid': adviserUid,
    'adviserName': adviserName,
    'startsAt': startsAt,
    'durationMins': durationMins,
    'status': status.name,
    'createdAt': createdAt,
    'bookedGroupId': bookedGroupId,
    'bookedGroupName': bookedGroupName,
    'bookedByUid': bookedByUid,
    'bookedByName': bookedByName,
  };

  factory Slot.fromMap(Map<String, dynamic> m, String id) => Slot(
    id: id,
    adviserUid: (m['adviserUid'] as String?) ?? '',
    adviserName: (m['adviserName'] as String?) ?? '',
    startsAt: (m['startsAt'] as int?) ?? 0,
    durationMins: (m['durationMins'] as int?) ?? 30,
    status: SlotStatus.fromName(m['status'] as String?),
    createdAt: (m['createdAt'] as int?) ?? 0,
    bookedGroupId: m['bookedGroupId'] as String?,
    bookedGroupName: m['bookedGroupName'] as String?,
    bookedByUid: m['bookedByUid'] as String?,
    bookedByName: m['bookedByName'] as String?,
  );
}