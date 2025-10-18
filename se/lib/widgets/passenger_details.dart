import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PassengerDetails extends StatelessWidget {
  final String passengerId;

  const PassengerDetails({super.key, required this.passengerId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(passengerId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(title: Text("Loading passenger..."));
        }
        final passengerData = snapshot.data!.data() as Map<String, dynamic>?;
        if (passengerData == null) {
          return const SizedBox.shrink();
        }

        final name = passengerData['displayName'] ?? 'N/A';
        final age = passengerData['age'] ?? 'N/A';
        final gender = passengerData['gender'] ?? 'N/A';

        return ListTile(
          title: Text(name),
          subtitle: Text('Age: $age, Gender: $gender'),
        );
      },
    );
  }
}
