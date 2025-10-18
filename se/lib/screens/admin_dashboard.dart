import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int totalRides = 0;
  int totalBookings = 0;
  int activeUsers = 0;
  double totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      // Get total rides
      final ridesSnapshot =
          await FirebaseFirestore.instance.collection('rides').get();

      // Get total bookings
      final bookingsSnapshot =
          await FirebaseFirestore.instance.collection('bookings').get();

      // Get active users (users with FCM tokens)
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('fcmToken', isNull: false)
          .get();

      // Calculate total revenue
      double revenue = 0.0;
      for (var booking in bookingsSnapshot.docs) {
        final data = booking.data();
        if (data['fare'] != null && data['status'] == 'confirmed') {
          revenue += double.tryParse(data['fare'].toString()) ?? 0.0;
        }
      }

      setState(() {
        totalRides = ridesSnapshot.docs.length;
        totalBookings = bookingsSnapshot.docs.length;
        activeUsers = usersSnapshot.docs.length;
        totalRevenue = revenue;
      });
    } catch (e) {
      print('Error loading analytics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('📊 Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(
                themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo, Colors.indigo[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.analytics, size: 48, color: Colors.white),
                    const SizedBox(height: 8),
                    const Text(
                      'Ride Sharing Analytics',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Real-time insights and metrics',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Stats Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2, // More vertical space
                children: [
                  _buildStatCard(
                    icon: Icons.directions_car,
                    title: 'Total Rides',
                    value: totalRides.toString(),
                    color: Colors.green,
                  ),
                  _buildStatCard(
                    icon: Icons.bookmark,
                    title: 'Total Bookings',
                    value: totalBookings.toString(),
                    color: Colors.blue,
                  ),
                  _buildStatCard(
                    icon: Icons.people,
                    title: 'Active Users',
                    value: activeUsers.toString(),
                    color: Colors.orange,
                  ),
                  _buildStatCard(
                    icon: Icons.currency_rupee,
                    title: 'Total Revenue',
                    value: '₹${totalRevenue.toStringAsFixed(2)}',
                    color: Colors.purple,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent Activity
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Recent Rides
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rides')
                    .orderBy('createdAt', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return Column(
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.directions_car,
                              color: Colors.green),
                          title: Text('${data['from']} → ${data['to']}'),
                          subtitle: Text(
                              '₹${data['fare']} • ${data['date']} ${data['time']}'),
                          trailing: const Text(
                            'Posted',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Recent Bookings
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('bookings')
                    .orderBy('createdAt', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return Column(
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.bookmark,
                              color: Colors.blue),
                          title: Text('${data['from']} → ${data['to']}'),
                          subtitle: Text(
                              '₹${data['fare']} • ${data['date']} ${data['time']}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: data['status'] == 'confirmed'
                                  ? Colors.green
                                  : Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              data['status']?.toUpperCase() ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
