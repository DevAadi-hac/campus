import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'live_location_screen.dart';

class DriverBookings extends StatelessWidget {
  const DriverBookings({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("You need to be logged in.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Booked Rides")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("bookings")
            .where('driverId', isEqualTo: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No bookings on your rides yet"));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (c, i) {
              final booking = docs[i].data();
              final bookingId = docs[i].id;
              final isConfirmed = booking['status'] == 'confirmed';

              return Card(
                margin: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.indigo, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${booking['from'] ?? ''} → ${booking['to'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isConfirmed ? Colors.green[100] : Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              booking['status']?.toUpperCase() ?? '',
                              style: TextStyle(
                                color: isConfirmed ? Colors.green[800] : Colors.orange[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (booking['fare'] != null)
                        Text('Fare: ₹${booking['fare']}', style: const TextStyle(fontSize: 16)),
                      if (booking['date'] != null && booking['time'] != null)
                        Text('Date: ${booking['date']} | Time: ${booking['time']}', style: const TextStyle(fontSize: 15)),
                      // I'll need rider's name and contact. I'll assume it's in the booking document.
                      if (booking['riderName'] != null)
                        Text('Rider: ${booking['riderName']}', style: const TextStyle(fontSize: 14)),
                      if (booking['riderContact'] != null)
                        Text('Rider Contact: ${booking['riderContact']}', style: const TextStyle(fontSize: 14)),
                      
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        alignment: WrapAlignment.end,
                        children: [
                          if (isConfirmed) ...[
                            ElevatedButton.icon(
                              onPressed: () {
                                final rideId = booking['rideId'];
                                if (rideId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LiveLocationScreen(rideId: rideId),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Could not open map. Ride information is missing.')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.map, size: 18),
                              label: const Text('View on Map'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                final riderId = booking['userId'];
                                final rideIdForChat = booking['rideId'];
                                final riderContact = booking['riderContact'];
                                if (riderId != null && rideIdForChat != null && riderContact != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        rideId: rideIdForChat,
                                        otherUserId: riderId,
                                        otherUserName: booking['riderName'] ?? 'Rider',
                                        otherUserPhone: riderContact,
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Could not open chat. Rider information is missing.')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.chat, size: 18),
                              label: const Text('Chat with Rider'),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
