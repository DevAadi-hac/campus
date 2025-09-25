import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FindRides extends StatelessWidget {
  const FindRides({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Find Rides")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('rides').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No rides available"));
          return ListView(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text("${data['from']} → ${data['to']}"),
                  subtitle: Text(
                      "Driver: ${data['driverName']}\nFare: ₹${data['fare']}\nDate: ${data['date']} - ${data['time']}"),
                  trailing: ElevatedButton(
                    onPressed: () {
                      // Booking logic here
                    },
                    child: const Text("Book"),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
