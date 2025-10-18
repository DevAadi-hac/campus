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
import 'driver_bookings.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  bool _sharingLocation = false;
  final Location _location = Location();

  @override
  void initState() {
    super.initState();
    _checkInitialLocationSharing();
  }

  void _checkInitialLocationSharing() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.user == null) return;
    final doc = await FirebaseFirestore.instance.collection("drivers").doc(auth.user!.uid).get();
    if (doc.exists && doc.data()!.containsKey('sharingLocation')) {
      if (mounted) {
        setState(() {
          _sharingLocation = doc.data()!['sharingLocation'] as bool;
        });
      }
    }
  }

  Future<void> _toggleLocationSharing(bool share, String uid) async {
    if (share) {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestedPermission = await Geolocator.requestPermission();
        if (requestedPermission == LocationPermission.denied || requestedPermission == LocationPermission.deniedForever) {
          _showPermissionDialog();
          return; // Don't enable sharing if permission is denied
        }
      }
      _startLocationUpdates(uid);
    } else {
      _stopLocationUpdates(uid);
    }
    if (mounted) {
      setState(() {
        _sharingLocation = share;
      });
    }
  }

  void _startLocationUpdates(String uid) {
    _location.onLocationChanged.listen((loc) {
      if (_sharingLocation) {
        FirebaseFirestore.instance.collection("drivers").doc(uid).set({
          "sharingLocation": true,
          "lat": loc.latitude,
          "lng": loc.longitude,
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  void _stopLocationUpdates(String uid) {
    FirebaseFirestore.instance.collection("drivers").doc(uid).update({
      "sharingLocation": false,
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text('To share your live location, please enable location permissions in your device settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in.")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Driver Dashboard"),
        elevation: 0,
      ),
      drawer: _buildDrawer(auth),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(auth),
            const SizedBox(height: 24),
            _buildStatsGrid(user.uid),
            const SizedBox(height: 24),
            _buildActionsGrid(context),
            const SizedBox(height: 24),
            _buildLocationSharingCard(user.uid),
            const SizedBox(height: 24),
            const Text("Recent Feedback", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildFeedbackList(user.uid),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(AuthService auth) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(auth.profile?['displayName'] ?? 'Driver', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            accountEmail: Text(auth.user?.phoneNumber ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(auth.profile?['displayName']?.substring(0, 1).toUpperCase() ?? 'D', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
          ),
          ListTile(leading: const Icon(Icons.directions_car_outlined), title: const Text("Post a Ride"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostRide()))),
          ListTile(leading: const Icon(Icons.list_alt_outlined), title: const Text("My Posted Rides"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRides()))),
          ListTile(leading: const Icon(Icons.people_outline), title: const Text("Passenger Bookings"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverBookings()))),
          const Divider(),
          ListTile(leading: const Icon(Icons.swap_horiz_outlined), title: const Text("Switch to Rider"), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiderHome()))),
          ListTile(leading: const Icon(Icons.bookmark_border_outlined), title: const Text("My Bookings (as Rider)"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookings()))),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout), title: const Text("Logout"), onTap: () async {
            await auth.signOut();
            Navigator.popUntil(context, (route) => route.isFirst);
          }),
        ],
      ),
    );
  }

  Widget _buildHeader(AuthService auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Welcome back,", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        Text(auth.profile?['displayName'] ?? 'Driver', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatsGrid(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('drivers').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final totalRides = data?['totalRides'] as int? ?? 0; // Assuming you track this

        return GridView.count(
          crossAxisCount: 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 3.5,
          children: [
            _buildStatCard("Total Rides", totalRides.toString(), Colors.blue),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildActionCard(context, "Post a New Ride", Icons.add_road_outlined, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostRide()))),
        _buildActionCard(context, "View My Rides", Icons.list_alt_outlined, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRides()))),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSharingCard(String uid) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        value: _sharingLocation,
        onChanged: (val) => _toggleLocationSharing(val, uid),
        title: const Text("Share Live Location", style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text("Allow riders to see your real-time location on the map."),
        secondary: Icon(Icons.location_on, color: _sharingLocation ? Colors.blue : Colors.grey, size: 32),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildFeedbackList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("drivers").doc(uid).collection("ratings").orderBy("createdAt", descending: true).limit(5).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            elevation: 0,
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.rate_review_outlined, size: 50, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    const Text("No feedback yet.", style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (c, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final rating = data['rating'] as num? ?? 0;
            final feedback = data['feedback'] as String? ?? "No comment provided.";
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  child: Text(rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                title: Row(
                  children: List.generate(5, (index) => Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 20,
                  )),
                ),
                subtitle: Text('"$feedback"', style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
            );
          },
        );
      },
    );
  }
}