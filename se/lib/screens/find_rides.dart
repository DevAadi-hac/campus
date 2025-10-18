import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:se/screens/passenger_details_screen.dart';

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
              final seatsAvailable = data['seatsAvailable'] ?? 0;

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
                                    Text('${averageRating.toStringAsFixed(1)} ($ratingCount)')
                                  ],
                                ),
                              if (ratingCount == 0)
                                const Text('(New Driver)', style: TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ),
                          Text("Fare: ₹${data['fare']}\nDate: ${data['date']} - ${data['time']}"),
                          Text("Seats Available: $seatsAvailable")
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: seatsAvailable > 0
                            ? () {
                                final auth = Provider.of<AuthService>(context, listen: false);
                                final user = auth.user;

                                if (user == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please log in to book a ride.')),
                                  );
                                  return;
                                }

                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    int numberOfSeats = 1;
                                    return AlertDialog(
                                      title: const Text('Number of Seats'),
                                      content: TextField(
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          numberOfSeats = int.tryParse(value) ?? 1;
                                        },
                                        decoration: const InputDecoration(
                                          labelText: 'Enter number of seats',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            if (numberOfSeats > seatsAvailable) {
                                              Navigator.of(context).pop();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Only $seatsAvailable seats available.')),
                                              );
                                              return;
                                            }

                                            Navigator.of(context).pop();
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => PassengerDetailsScreen(
                                                  numberOfSeats: numberOfSeats,
                                                  ride: {
                                                    'id': doc.id,
                                                    ...data,
                                                  },
                                                ),
                                              ),
                                            );

                                            if (result == true) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Ride booked successfully!')),
                                              );
                                            }
                                          },
                                          child: const Text('Confirm'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }
                            : null,
                        child: Text(seatsAvailable > 0 ? "Book" : "Full"),
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