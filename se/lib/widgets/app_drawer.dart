import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/driver_home.dart';
import '../screens/rider_home.dart';
import '../screens/my_rides.dart';
import '../screens/my_bookings.dart';
import '../screens/login_phone.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);

    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            child: Text("🚖 Campus Ride", style: TextStyle(fontSize: 22)),
          ),
          ListTile(
            leading: const Icon(Icons.directions_car),
            title: const Text("Driver Home"),
            onTap: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const DriverHome())),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text("Rider Home"),
            onTap: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const RiderHome())),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text("My Rides"),
            onTap: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const MyRides())),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark),
            title: const Text("My Bookings"),
            onTap: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const MyBookings())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: () async {
              await auth.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPhoneScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
