import 'package:cloud_firestore/cloud_firestore.dart';

class RideService {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference rides() => _db.collection('rides');
  static CollectionReference bookings() => _db.collection('bookings');

  static Future<String> postRide(Map<String, dynamic> data) async {
    final docRef = await rides().add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'seatsAvailable': data['seatsAvailable'] ?? 1,
      'passengers': [],
    });
    return docRef.id;
  }

  static Stream<QuerySnapshot> streamAvailableRides() {
    return rides()
        .where('seatsAvailable', isGreaterThan: 0)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> bookRide(Map<String, dynamic> ride, String userId) async {
    final rideId = ride['id'];
    final rideRef = rides().doc(rideId);

    await _db.runTransaction((transaction) async {
      final rideSnapshot = await transaction.get(rideRef);
      if (!rideSnapshot.exists) {
        throw Exception("Ride does not exist!");
      }

      final currentSeats = (rideSnapshot.data() as Map<String, dynamic>)['seatsAvailable'];
      if (currentSeats <= 0) {
        throw Exception("No seats available!");
      }

      transaction.update(rideRef, {
        'seatsAvailable': currentSeats - 1,
        'passengers': FieldValue.arrayUnion([userId]),
      });

      final bookingRef = bookings().doc();
      transaction.set(bookingRef, {
        ...ride,
        'rideId': rideId,
        'userId': userId,
        'status': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Stream<QuerySnapshot> streamUserBookings(String userId) {
    return bookings().where('userId', isEqualTo: userId).snapshots();
  }

  static Future<DocumentSnapshot> getRide(String rideId) {
    return rides().doc(rideId).get();
  }
}