import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class MyRides extends StatelessWidget {
  const MyRides({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Rides")),
      drawer: const AppDrawer(),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection("rides").snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No rides posted yet"));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (c, i) {
              final ride = docs[i].data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_car, color: Colors.indigo),
                  title: Text("${ride['from']} → ${ride['to']}"),
                  subtitle: Text("Fare: ₹${ride['fare']} | Driver: ${ride['driverName']}"),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == "edit") {
                        // open edit page (TODO)
                      } else if (value == "cancel") {
                        await docs[i].reference.delete();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: "edit", child: Text("Edit")),
                      const PopupMenuItem(value: "cancel", child: Text("Cancel")),
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
