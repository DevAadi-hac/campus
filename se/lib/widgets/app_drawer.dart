import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import '../screens/driver_home.dart';
import '../screens/rider_home.dart';
import '../screens/my_rides.dart';
import '../screens/my_bookings.dart';
import '../screens/admin_dashboard.dart';
import '../screens/login_phone.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);

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
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text("Admin Dashboard"),
            onTap: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const AdminDashboard())),
          ),
          const Divider(),
          ListTile(
            leading: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            title: Text(themeProvider.isDarkMode ? "Light Mode" : "Dark Mode"),
            onTap: () => themeProvider.toggleTheme(),
          ),
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
