import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../widgets/app_drawer.dart';
import 'package:campus_ride_sharing_step1/screens/payment_page.dart';
import 'package:geolocator/geolocator.dart';

class RiderHome extends StatefulWidget {
  const RiderHome({super.key});

  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  GoogleMapController? mapController;
  final LatLng _center = const LatLng(22.3072, 73.1812);

  Set<Polyline> _polylines = {};
  List<LatLng> _routeCoords = [];

  bool _sharingLocation = false;
  bool _showSimulation = false;
  List<LatLng> _simRoute = [];
  String? _lastDriverId;
  bool _showThankYou = false;

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  /// ✅ Fetch route using Google Directions API
  Future<void> _getRoute(LatLng origin, LatLng destination) async {
    const apiKey = "AIzaSyBZtnkBIygYn28_bCYKCHKIwquR3Xz6ZYI"; // 🔑 your Google API key here
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data["routes"].isNotEmpty) {
      final points = data["routes"][0]["overview_polyline"]["points"];
      _routeCoords = _decodePolyline(points);

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId("route"),
          visible: true,
          width: 5,
          color: Colors.blue,
          points: _routeCoords,
        ));
      });
    }
  }

  List<LatLng> _decodePolyline(String poly) {
    List<LatLng> points = [];
    int index = 0, len = poly.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _requestLocationPermission() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Location'),
        content: const Text(
            'To share your location with the driver, please enable location services.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Request location permission using geolocator
              await Geolocator.requestPermission();
              // Optionally, check if location services are enabled
              // bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
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

  void startRouteSimulation() {
    setState(() {
      _showSimulation = true;
    });
  }

  void completeRouteSimulation() {
    setState(() {
      _showSimulation = false;
      _showThankYou = true;
    });
    // Show thank you and feedback dialog
    Future.delayed(const Duration(milliseconds: 500), () {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ThankYouFeedbackDialog(driverId: _lastDriverId ?? "demo_driver"),
      ).then((_) {
        setState(() { _showThankYou = false; });
      });
    });
  }

  Future<List<LatLng>> _fetchRouteForSimulation(LatLng origin, LatLng destination) async {
    const apiKey = "AIzaSyBZtnkBIygYn28_bCYKCHKIwquR3Xz6ZYI";
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey";
    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);
    if (data["routes"].isNotEmpty) {
      final points = data["routes"][0]["overview_polyline"]["points"];
      return _decodePolyline(points);
    }
    return [origin, destination];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rider Home")),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // 🌍 Map with driver markers + route
          StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection("drivers")
                .where("sharingLocation", isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              final markers = <Marker>{};
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data();
                  if (data['lat'] != null && data['lng'] != null) {
                    final driverPos = LatLng(data['lat'], data['lng']);
                    markers.add(Marker(
                      markerId: MarkerId(doc.id),
                      position: driverPos,
                      infoWindow: InfoWindow(title: data['name'] ?? "Driver"),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue),
                    ));
                  }
                }
              }
              return GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition:
                    CameraPosition(target: _center, zoom: 13),
                markers: markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              );
            },
          ),

          // 📌 Bottom sheet with rides
          DraggableScrollableSheet(
            initialChildSize: 0.25,
            minChildSize: 0.2,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 5,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Text(
                      "Available Rides",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder(
                        stream: FirebaseFirestore.instance
                            .collection("rides")
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final docs = snapshot.data!.docs;
                          if (docs.isEmpty) {
                            return const Center(
                                child: Text("No rides available"));
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: docs.length,
                            itemBuilder: (c, i) {
                              final ride = docs[i].data();
                              final rideId = docs[i].id;
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.directions_car, color: Colors.indigo),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              // Show place/landmark names instead of coordinates
                                              (ride['from'] ?? 'Unknown') + ' → ' + (ride['to'] ?? 'Unknown'),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              final from = ride['from'] as String?;
                                              final to = ride['to'] as String?;
                                              final driverId = ride['driverId'] as String?;

                                              if (from == null || to == null || driverId == null) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('This ride has incomplete data and cannot be booked.')),
                                                );
                                                return;
                                              }

                                              // Navigate to PaymentPage, pass ride info (including rideId)
                                              final rideWithId = Map<String, dynamic>.from(ride);
                                              rideWithId['id'] = rideId;
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => PaymentPage(ride: rideWithId),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                            child: const Text("Book"),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text("Fare: ₹${ride['fare']} | Date: ${ride['date']} | Time: ${ride['time']}", style: const TextStyle(fontSize: 14)),
                                      if (ride['costPerKm'] != null) Text("Cost per km: ₹${ride['costPerKm']}", style: const TextStyle(fontSize: 13)),
                                      if (ride['vehicleRegNo'] != null) Text("Vehicle Reg No: ${ride['vehicleRegNo']}", style: const TextStyle(fontSize: 13)),
                                      if (ride['driverContact'] != null) Text("Driver Contact: ${ride['driverContact']}", style: const TextStyle(fontSize: 13)),
                                      if (ride['vehiclePhoto'] != null && ride['vehiclePhoto'].toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: SizedBox(
                                            height: 80,
                                            child: Image.network(
                                              ride['vehiclePhoto'],
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
                    ),
                  ],
                ),
              );
            },
          ),
          // Toggle for sharing location with driver
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Share location with driver'),
                Switch(
                  value: _sharingLocation,
                  onChanged: (val) {
                    setState(() {
                      _sharingLocation = val;
                    });
                    if (val) {
                      _requestLocationPermission();
                    }
                  },
                ),
              ],
            ),
          ),
          if (_showSimulation)
            RouteSimulationOverlay(onComplete: completeRouteSimulation),
        ],
      ),
    );
  }
}

class RouteSimulationOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const RouteSimulationOverlay({required this.onComplete, super.key});

  @override
  State<RouteSimulationOverlay> createState() => _RouteSimulationOverlayState();
}

class _RouteSimulationOverlayState extends State<RouteSimulationOverlay> {
  double progress = 0;
  late final int duration;

  @override
  void initState() {
    super.initState();
    duration = 15; // 15 seconds
    _startSimulation();
  }

  void _startSimulation() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        progress += 1 / (duration * 3.3);
      });
      if (progress >= 1) {
        widget.onComplete();
        return false;
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Simulating your ride...', style: TextStyle(color: Colors.white, fontSize: 24)),
            const SizedBox(height: 30),
            LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: Colors.white24, color: Colors.green),
            const SizedBox(height: 20),
            Text('${(progress * duration).toInt()} / $duration sec', style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class ThankYouFeedbackDialog extends StatefulWidget {
  final String driverId;
  const ThankYouFeedbackDialog({required this.driverId, super.key});

  @override
  State<ThankYouFeedbackDialog> createState() => _ThankYouFeedbackDialogState();
}

class _ThankYouFeedbackDialogState extends State<ThankYouFeedbackDialog> {
  double _rating = 3.0;
  bool _submitted = false;

  Future<void> _submitFeedback() async {
    await FirebaseFirestore.instance
        .collection("drivers")
        .doc(widget.driverId)
        .collection("ratings")
        .add({"rating": _rating, "createdAt": FieldValue.serverTimestamp()});
    setState(() { _submitted = true; });
    await Future.delayed(const Duration(seconds: 2));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thank you for traveling!'),
      content: _submitted
          ? const Text('Feedback submitted!')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please rate your ride:'),
                Slider(
                  value: _rating,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _rating.toStringAsFixed(1),
                  onChanged: (val) => setState(() => _rating = val),
                ),
              ],
            ),
      actions: _submitted
          ? []
          : [
              TextButton(
                onPressed: _submitFeedback,
                child: const Text('Submit'),
              ),
            ],
    );
  }
}
