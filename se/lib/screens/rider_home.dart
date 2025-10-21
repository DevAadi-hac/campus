import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../widgets/app_drawer.dart';
import 'package:campus_ride_sharing_step1/screens/payment_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:campus_ride_sharing_step1/services/ride_service.dart';
import 'package:campus_ride_sharing_step1/screens/my_bookings.dart';
import 'package:campus_ride_sharing_step1/services/api_key.dart';
import 'package:campus_ride_sharing_step1/screens/passenger_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:campus_ride_sharing_step1/services/auth_service.dart';

class RiderHome extends StatefulWidget {
  const RiderHome({super.key});

  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  GoogleMapController? _mapController;
  final LatLng _center = const LatLng(22.3072, 73.1812); // Vadodara

  bool _sharingLocation = false;

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  void _toggleLocationSharing(bool share) {
    if (share) {
      _requestLocationPermission();
    }
    setState(() {
      _sharingLocation = share;
    });
    // Logic to start/stop sharing location would go here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Find a Ride"),
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          _buildGoogleMap(),
          _buildAvailableRidesSheet(),
        ],
      ),
    );
  }

  void _removeRide(String rideId) {
    FirebaseFirestore.instance.collection('rides').doc(rideId).delete();
  }

  bool _isRideOutdated(Map<String, dynamic> ride) {
    final rideDate = ride['date'] as String?;
    final rideTime = ride['time'] as String?;
    if (rideDate == null || rideTime == null) {
      return false;
    }
    try {
      final rideDateTime = DateTime.parse('$rideDate $rideTime');
      return rideDateTime.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  Widget _buildGoogleMap() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("drivers").where("sharingLocation", isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error loading map data: ${snapshot.error}"));
        }

        final markers = <Marker>{};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['lat'] != null && data['lng'] != null) {
              markers.add(Marker(
                markerId: MarkerId(doc.id),
                position: LatLng(data['lat'], data['lng']),
                infoWindow: InfoWindow(title: data['name'] ?? "Driver"),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ));
            }
          }
        }
        return GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(target: _center, zoom: 13),
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          padding: const EdgeInsets.only(bottom: 200), // Adjust padding for the sheet
        );
      },
    );
  }

  Widget _buildAvailableRidesSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.25,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.2))],
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Available Rides", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        const Text("Share Location"),
                        Switch(
                          value: _sharingLocation,
                          onChanged: _toggleLocationSharing,
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection("rides").where('seatsAvailable', isGreaterThan: 0).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error loading rides: ${snapshot.error}"));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }
                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(8.0),
                      itemCount: docs.length,
                      itemBuilder: (c, i) {
                        final ride = docs[i].data() as Map<String, dynamic>;
                        final rideId = docs[i].id;
                        return _buildRideCard(ride, rideId);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, String rideId) {
    final seatsAvailable = ride['seatsAvailable'] ?? 0;
    final driverId = ride['driverId'] as String?;
    final isOutdated = _isRideOutdated(ride);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: (ride['vehiclePhoto'] != null && ride['vehiclePhoto'].toString().isNotEmpty)
                  ? CircleAvatar(backgroundImage: NetworkImage(ride['vehiclePhoto']))
                  : const CircleAvatar(child: Icon(Icons.directions_car, color: Colors.white)),
              title: Text("${ride['from'] ?? 'Unknown'} → ${ride['to'] ?? 'Unknown'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: (driverId == null || driverId.isEmpty)
                  ? const Text("Driver not specified", style: TextStyle(color: Colors.red))
                  : FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('drivers').doc(driverId).get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text('Error loading driver', style: TextStyle(color: Colors.red));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text('Driver: loading...');
                        }
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Text('Driver not found', style: TextStyle(color: Colors.red));
                        }
                        final driverData = snapshot.data!.data() as Map<String, dynamic>?;
                        final driverName = driverData?['displayName'] ?? 'Driver';
                        final avgRating = driverData?['averageRating'] as double? ?? 0.0;
                        return Text('$driverName (⭐ ${avgRating.toStringAsFixed(1)})');
                      },
                    ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  _buildInfoChip(Icons.calendar_today, "${ride['date']} at ${ride['time']}"),
                  _buildInfoChip(Icons.airline_seat_recline_normal, '$seatsAvailable Seats Left', color: Colors.green),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("₹${ride['fare']}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                if (isOutdated)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Chip(
                        label: Text("Expired"),
                        backgroundColor: Colors.grey,
                      ),
                      SizedBox(
                        height: 28, // To make it smaller
                        child: TextButton.icon(
                          onPressed: () => _removeRide(rideId),
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          label: const Text("Remove", style: TextStyle(color: Colors.red, fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  )
                else if (driverId != null && driverId == FirebaseAuth.instance.currentUser?.uid)
                  const Chip(
                    label: Text("Your Ride"),
                    backgroundColor: Colors.orange,
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _showSeatSelector(context, ride, rideId, seatsAvailable),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text("Book Now"),
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  ),
              ],
            ),
            const Divider(height: 20),
            ExpansionTile(
              title: const Text('More Info', style: TextStyle(fontWeight: FontWeight.w600)),
              tilePadding: EdgeInsets.zero,
              children: [
                _buildDetailRow(Icons.person_outline, 'Driver Contact', ride['driverContact'] ?? 'N/A'),
                _buildDetailRow(Icons.car_rental_outlined, 'Vehicle', "${ride['vehicleName'] ?? 'N/A'} (${ride['vehicleType'] ?? 'N/A'})"),
                _buildDetailRow(Icons.pin_outlined, 'Vehicle Number', ride['vehicleRegNo'] ?? 'N/A'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Text('$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  void _showSeatSelector(BuildContext context, Map<String, dynamic> ride, String rideId, int seatsAvailable) {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to book a ride.')));
      return;
    }

    int numberOfSeats = 1;
    List<int> seatOptions = List<int>.generate(seatsAvailable, (i) => i + 1);
    if (seatOptions.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Select Number of Seats'),
              content: DropdownButton<int>(
                value: numberOfSeats,
                isExpanded: true,
                onChanged: (int? newValue) {
                  if (newValue != null) setState(() => numberOfSeats = newValue);
                },
                items: seatOptions.map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(value: value, child: Text("$value Seat${value > 1 ? 's' : ''}"));
                }).toList(),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    final rideWithId = Map<String, dynamic>.from(ride);
                    rideWithId['id'] = rideId;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PassengerDetailsScreen(numberOfSeats: numberOfSeats, ride: rideWithId),
                      ),
                    );
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color ?? Colors.grey[600]),
      label: Text(text, style: TextStyle(color: color ?? Colors.grey[700])),
      backgroundColor: color?.withOpacity(0.1) ?? Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text("No rides available right now.", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text("Please check back later.", style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
