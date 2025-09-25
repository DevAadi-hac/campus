class RideModel {
  String id;
  String from;
  String to;
  DateTime when;
  String driverId;
  String driverName;
  double fare;
  int seatsAvailable;

  RideModel({
    required this.id,
    required this.from,
    required this.to,
    required this.when,
    required this.driverId,
    required this.driverName,
    required this.fare,
    required this.seatsAvailable,
  });

  factory RideModel.fromMap(String id, Map<String, dynamic> m) {
    return RideModel(
      id: id,
      from: m['from'] ?? '',
      to: m['to'] ?? '',
      when: (m['when'] as Timestamp).toDate(),
      driverId: m['driverId'] ?? '',
      driverName: m['driverName'] ?? '',
      fare: (m['fare'] ?? 0).toDouble(),
      seatsAvailable: (m['seatsAvailable'] ?? 1),
    );
  }
}
