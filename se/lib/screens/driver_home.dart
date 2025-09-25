import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import 'post_ride.dart';
import 'my_rides.dart';
import 'rider_home.dart';
import 'my_bookings.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  bool sharingLocation = false;
  Location location = Location();
  Stream<LocationData>? locationStream;

  Future<void> _startLocationSharing(String uid) async {
    locationStream = location.onLocationChanged;
    locationStream!.listen((loc) async {
      await FirebaseFirestore.instance.collection("drivers").doc(uid).set({
        "sharingLocation": true,
        "lat": loc.latitude,
        "lng": loc.longitude,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _stopLocationSharing(String uid) async {
    await FirebaseFirestore.instance.collection("drivers").doc(uid).update({
      "sharingLocation": false,
    });
  }

  Future<void> _requestLocationPermissionAndShare(String uid) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Location'),
        content: const Text('To share your location, please enable location services.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Request location permission using geolocator
              await Geolocator.requestPermission();
              _startLocationSharing(uid);
            },
            child: const Text('Turn On'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Home"),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ✅ Driver header with rating
            Container(
              color: Colors.blue,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    child: Icon(Icons.person, size: 40),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    auth.profile?['displayName'] ?? 'Driver',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    auth.user?.phoneNumber ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('drivers')
                        .doc(auth.user!.uid)
                        .collection('ratings')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Text("Rating: --",
                            style: TextStyle(color: Colors.white));
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const Text("Rating: No ratings yet",
                            style: TextStyle(color: Colors.white));
                      }
                      final ratings = docs
                          .map((d) => (d['rating'] as num).toDouble())
                          .toList();
                      final avg =
                          ratings.reduce((a, b) => a + b) / ratings.length;
                      return Text(
                        "⭐ ${avg.toStringAsFixed(1)} / 5.0",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      );
                    },
                  ),
                ],
              ),
            ),

            // 📌 Drawer options
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text("Post a Ride"),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PostRide()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text("My Rides"),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyRides()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text("Rider Home (Map)"),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RiderHome()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text("My Bookings"),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyBookings()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () async {
                await auth.signOut();
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(auth.profile?['displayName'] ?? 'Driver'),
                subtitle: Text(
                    "${auth.user?.phoneNumber ?? ''}\nVehicle: ${auth.profile?['vehicle'] ?? 'Not added'}"),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: sharingLocation,
              onChanged: (val) async {
                setState(() => sharingLocation = val);
                if (val) {
                  await _requestLocationPermissionAndShare(auth.user!.uid);
                } else {
                  _stopLocationSharing(auth.user!.uid);
                }
              },
              title: const Text("Share my live location with riders"),
              secondary: const Icon(Icons.location_on, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            const Text(
              "Recent Feedback",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection("drivers")
                    .doc(auth.user!.uid)
                    .collection("ratings")
                    .orderBy("createdAt", descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Text("No feedback yet.");
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (c, i) {
                      final data = docs[i].data();
                      return ListTile(
                        leading:
                            const Icon(Icons.star, color: Colors.orangeAccent),
                        title: Text("⭐ ${data['rating']}"),
                        subtitle: Text(data['feedback'] ?? ""),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
