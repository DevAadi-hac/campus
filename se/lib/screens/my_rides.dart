import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyRides extends StatefulWidget {
  const MyRides({super.key});

  @override
  State<MyRides> createState() => _MyRidesState();
}

class _MyRidesState extends State<MyRides> {
  Future<void> _completeRide(String rideId) async {
    final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
    final bookingsSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('rideId', isEqualTo: rideId)
        .get();

    WriteBatch batch = FirebaseFirestore.instance.batch();

    batch.update(rideRef, {'status': 'completed'});

    for (var doc in bookingsSnapshot.docs) {
      batch.update(doc.reference, {'status': 'completed'});
    }

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ride marked as completed!'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _cancelRide(DocumentReference rideRef) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text(
            'Are you sure you want to cancel this ride? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes')),
        ],
      ),
    );

    if (confirm == true) {
      await rideRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ride cancelled.'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("My Rides")),
        body: const Center(child: Text("Please log in to see your rides.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Posted Rides"), leading: const BackButton()),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("rides")
            .where('driverId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("You haven't posted any rides yet."));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            itemBuilder: (c, i) {
              final ride = docs[i].data() as Map<String, dynamic>;
              final rideId = docs[i].id;
              final status = ride['status'] ?? 'active';

              Color statusColor;
              String statusText;

              switch (status) {
                case 'completed':
                  statusColor = Colors.green;
                  statusText = 'COMPLETED';
                  break;
                case 'cancelled':
                  statusColor = Colors.red;
                  statusText = 'CANCELLED';
                  break;
                default:
                  statusColor = Colors.blue;
                  statusText = 'ACTIVE';
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.directions_car,
                          color: Colors.indigo, size: 40),
                      title: Text("${ride['from']} → ${ride['to']}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                              "On: ${ride['date']} at ${ride['time']}"),
                          const SizedBox(height: 4),
                          Text(
                              "Fare: ₹${ride['fare']} | Seats: ${ride['seatsAvailable']}"),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == "complete") {
                            _completeRide(rideId);
                          } else if (value == "cancel") {
                            _cancelRide(docs[i].reference);
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (status != 'completed')
                            const PopupMenuItem(
                                value: "complete",
                                child: Text("Mark as Complete")),
                          const PopupMenuItem(
                              value: "cancel", child: Text("Cancel Ride")),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Status: $statusText",
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}