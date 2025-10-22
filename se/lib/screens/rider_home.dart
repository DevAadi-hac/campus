import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../widgets/app_drawer.dart';
import '../widgets/ride_search_card.dart';
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

                    final docs = snapshot.data?.docs ?? [];

                    // Always show the search card as the first scrollable item so it won't overflow the sheet.
                    if (docs.isEmpty) {
                      return ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(8.0),
                        children: [
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: RideSearchCard()),
                          const SizedBox(height: 8),
                          _buildEmptyState(),
                        ],
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(8.0),
                      itemCount: docs.length + 1, // +1 for the search card
                      itemBuilder: (c, i) {
                        if (i == 0) return const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: RideSearchCard());
                        final idx = i - 1;
                        final ride = docs[idx].data() as Map<String, dynamic>;
                        final rideId = docs[idx].id;
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

    return _SimpleExpandableRideCard(
      ride: ride,
      rideId: rideId,
      seatsAvailable: seatsAvailable,
      driverId: driverId,
      isOutdated: isOutdated,
      onRemoveRide: _removeRide,
      onShowSeatSelector: _showSeatSelector,
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

  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color ?? Colors.grey[700]),
      label: Text(text, style: TextStyle(fontSize: 12, color: color ?? Colors.grey[700])),
      backgroundColor: (color ?? Colors.grey[700])!.withOpacity(0.1),
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

class _SimpleExpandableRideCard extends StatefulWidget {
  final Map<String, dynamic> ride;
  final String rideId;
  final int seatsAvailable;
  final String? driverId;
  final bool isOutdated;
  final Function(String) onRemoveRide;
  final Function(BuildContext, Map<String, dynamic>, String, int) onShowSeatSelector;

  const _SimpleExpandableRideCard({
    required this.ride,
    required this.rideId,
    required this.seatsAvailable,
    required this.driverId,
    required this.isOutdated,
    required this.onRemoveRide,
    required this.onShowSeatSelector,
  });

  @override
  State<_SimpleExpandableRideCard> createState() => _SimpleExpandableRideCardState();
}

class _SimpleExpandableRideCardState extends State<_SimpleExpandableRideCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic ride info
            ListTile(
              leading: (widget.ride['vehiclePhoto'] != null && widget.ride['vehiclePhoto'].toString().isNotEmpty)
                  ? CircleAvatar(backgroundImage: NetworkImage(widget.ride['vehiclePhoto']))
                  : const CircleAvatar(child: Icon(Icons.directions_car, color: Colors.white)),
              title: Text("${widget.ride['from'] ?? 'Unknown'} → ${widget.ride['to'] ?? 'Unknown'}", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: (widget.driverId == null || widget.driverId!.isEmpty)
                  ? const Text("Driver not specified", style: TextStyle(color: Colors.red))
                  : FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).get(),
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
            
            // Date, time, and seats info
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  _buildInfoChip(Icons.calendar_today, "${widget.ride['date']} at ${widget.ride['time']}"),
                  _buildInfoChip(Icons.airline_seat_recline_normal, '${widget.seatsAvailable} Seats Left', color: Colors.green),
                ],
              ),
            ),
            
            // Price and action buttons (responsive to avoid overflow)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    "₹${widget.ride['fare']}",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // View Details button
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                        label: Text(_isExpanded ? 'Hide' : 'View'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                      if (widget.isOutdated) ...[
                        const Chip(
                          label: Text("Expired"),
                          backgroundColor: Colors.grey,
                        ),
                        SizedBox(
                          height: 28,
                          child: TextButton.icon(
                            onPressed: () => widget.onRemoveRide(widget.rideId),
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            label: const Text("Remove", style: TextStyle(color: Colors.red, fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                      ] else if (widget.driverId != null && widget.driverId == FirebaseAuth.instance.currentUser?.uid) ...[
                        const Chip(
                          label: Text("Your Ride"),
                          backgroundColor: Colors.orange,
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => widget.onShowSeatSelector(context, widget.ride, widget.rideId, widget.seatsAvailable),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text("Book Now"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            // Expanded details section - only show actual posted fields
            if (_isExpanded) ...[
              const Divider(height: 20),
              _buildExpandedDetails(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ride Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        
        // Only show fields that are actually posted in the ride
        _buildDetailRow(Icons.person_outline, 'Driver Contact', widget.ride['driverContact'] ?? 'N/A'),
        _buildDetailRow(Icons.directions_car, 'Vehicle', "${widget.ride['vehicleName'] ?? 'N/A'} (${widget.ride['vehicleType'] ?? 'N/A'})"),
        _buildDetailRow(Icons.confirmation_number, 'Vehicle Number', widget.ride['vehicleRegNo'] ?? 'N/A'),
        _buildDetailRow(Icons.access_time, 'Departure Time', "${widget.ride['date']} at ${widget.ride['time']}"),
        _buildDetailRow(Icons.people, 'Available Seats', '${widget.seatsAvailable}'),
        _buildDetailRow(Icons.attach_money, 'Fare per Person', '₹${widget.ride['fare']}'),
        if (widget.ride['costPerKm'] != null)
          _buildDetailRow(Icons.speed, 'Cost per KM', '₹${widget.ride['costPerKm']}'),
      ],
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

  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color ?? Colors.grey[700]),
      label: Text(text, style: TextStyle(fontSize: 12, color: color ?? Colors.grey[700])),
      backgroundColor: (color ?? Colors.grey[700])!.withOpacity(0.1),
    );
  }
}
