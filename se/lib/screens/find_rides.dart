import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FindRides extends StatelessWidget {
  const FindRides({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Find Rides")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rides').snapshots(),
        builder: (context, rideSnapshot) {
          if (!rideSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = rideSnapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No rides available"));
          return ListView(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final driverId = data['driverId'];

              return Card(
                margin: const EdgeInsets.all(8),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(driverId).snapshots(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const ListTile(title: Text("Loading driver info..."));
                    }
                    final driverData = userSnapshot.data!.data() as Map<String, dynamic>?;
                    final driverName = driverData?['name'] ?? 'N/A';
                    final averageRating = driverData?['averageRating'] as double? ?? 0.0;
                    final ratingCount = driverData?['ratingCount'] as int? ?? 0;

                    return ListTile(
                      title: Text("${data['from']} → ${data['to']}"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text("Driver: $driverName"),
                              const SizedBox(width: 8),
                              if (ratingCount > 0)
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    Text('${averageRating.toStringAsFixed(1)} ($ratingCount)'),
                                  ],
                                ),
                              if (ratingCount == 0)
                                const Text('(New Driver)', style: TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ),
                          Text("Fare: ₹${data['fare']}\nDate: ${data['date']} - ${data['time']}"),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          final auth = Provider.of<AuthService>(context, listen: false);
                          final user = auth.user;
                          final profile = auth.profile;

                          if (user == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please log in to book a ride.')),
                            );
                            return;
                          }

                          await FirebaseFirestore.instance.collection('bookings').add({
                            'rideId': doc.id,
                            'driverId': data['driverId'],
                            'userId': user.uid,
                            'riderName': profile?['displayName'] ?? 'N/A',
                            'riderContact': user.phoneNumber ?? 'N/A',
                            'from': data['from'],
                            'to': data['to'],
                            'fare': data['fare'],
                            'date': data['date'],
                            'time': data['time'],
                            'status': 'confirmed',
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ride booked successfully!')),
                          );
                        },
                        child: const Text("Book"),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
