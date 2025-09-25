import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'feedback_page.dart';

class MyBookings extends StatefulWidget {
  const MyBookings({super.key});

  @override
  State<MyBookings> createState() => _MyBookingsState();
}

class _MyBookingsState extends State<MyBookings> {


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Bookings")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection("bookings").snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No bookings yet"));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (c, i) {
              final booking = docs[i].data();
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
                          const Icon(Icons.directions_car, color: Colors.indigo, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Ride: ${booking['rideId'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: booking['status'] == 'confirmed' ? Colors.green[100] : Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              booking['status']?.toUpperCase() ?? '',
                              style: TextStyle(
                                color: booking['status'] == 'confirmed' ? Colors.green[800] : Colors.orange[800],
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
                      if (booking['costPerKm'] != null)
                        Text('Cost per km: ₹${booking['costPerKm']}', style: const TextStyle(fontSize: 14)),
                      if (booking['vehicleRegNo'] != null)
                        Text('Vehicle Reg No: ${booking['vehicleRegNo']}', style: const TextStyle(fontSize: 14)),
                      if (booking['driverContact'] != null)
                        Text('Driver Contact: ${booking['driverContact']}', style: const TextStyle(fontSize: 14)),
                      if (booking['vehiclePhoto'] != null && booking['vehiclePhoto'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: SizedBox(
                            height: 80,
                            child: Image.network(
                              booking['vehiclePhoto'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Text('Vehicle photo unavailable'),
                            ),
                          ),
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
