import 'package:cloud_firestore/cloud_firestore.dart';

class RideService {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference rides() => _db.collection('rides');

  static Future<String> postRide(Map<String, dynamic> data) async {
    final docRef = await rides().add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'seatsAvailable': data['seatsAvailable'] ?? 1,
    });
    return docRef.id;
  }

  static Stream<QuerySnapshot> streamAvailableRides() {
    return rides()
        .where('seatsAvailable', isGreaterThan: 0)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}