import 'package:cloud_firestore/cloud_firestore.dart';

class RideModel {
  String id;
  String from;
  String to;
  DateTime when;
  String driverId;
  String driverName;
  double fare;
  int seatsAvailable;
  String vehicleType;
  String vehicleName;
  String vehiclePhotoPath;
  String driverPhotoPath;
  List<String> passengers;

  RideModel({
    required this.id,
    required this.from,
    required this.to,
    required this.when,
    required this.driverId,
    required this.driverName,
    required this.fare,
    required this.seatsAvailable,
    required this.vehicleType,
    required this.vehicleName,
    required this.vehiclePhotoPath,
    required this.driverPhotoPath,
    required this.passengers,
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
      vehicleType: m['vehicleType'] ?? '',
      vehicleName: m['vehicleName'] ?? '',
      vehiclePhotoPath: m['vehiclePhoto'] ?? '',
      driverPhotoPath: m['driverPhoto'] ?? '',
      passengers: List<String>.from(m['passengers'] ?? []),
    );
  }
}
