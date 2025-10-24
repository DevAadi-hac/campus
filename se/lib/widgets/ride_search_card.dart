import 'package:campus_ride_sharing_step1/screens/passenger_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class _LatLng {
  final double latitude;
  final double longitude;
  _LatLng(this.latitude, this.longitude);
}

class RideSearchCard extends StatefulWidget {
  const RideSearchCard({Key? key}) : super(key: key);

  @override
  State<RideSearchCard> createState() => _RideSearchCardState();
}

class _RideSearchCardState extends State<RideSearchCard> {
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  int _passengers = 1;
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  Future<_LatLng?> _geocode(String address) async {
    try {
      final places = await geocoding.locationFromAddress(address);
      if (places.isNotEmpty) {
        final p = places.first;
        return _LatLng(p.latitude, p.longitude);
      }
    } catch (_) {}
    return null;
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  bool _isNearbyRoute(Map<String, dynamic> ride, double fromLat, double fromLng,
      double toLat, double toLng) {
    // Try ride stored lat/lng fields if available
    final startLat = ride['startLat'] ?? ride['fromLat'] ?? ride['start']?['lat'];
    final startLng = ride['startLng'] ?? ride['fromLng'] ?? ride['start']?['lng'];
    final endLat = ride['endLat'] ?? ride['toLat'] ?? ride['end']?['lat'];
    final endLng = ride['endLng'] ?? ride['toLng'] ?? ride['end']?['lng'];

    if (startLat != null && startLng != null && endLat != null && endLng != null) {
      final sdist = _distanceMeters(startLat.toDouble(), startLng.toDouble(), fromLat, fromLng);
      final edist = _distanceMeters(endLat.toDouble(), endLng.toDouble(), toLat, toLng);
      if (sdist < 25000 && edist < 25000) return true;
      if (sdist < 15000 || edist < 15000) return true;
    }

    // If route points exist (stored as list of maps with lat,lng)
    if (ride['route'] != null && ride['route'] is List) {
      final List route = ride['route'];
      for (final point in route) {
        final plat = point['lat'];
        final plng = point['lng'];
        if (plat == null || plng == null) continue;
        final dFrom = _distanceMeters(plat.toDouble(), plng.toDouble(), fromLat, fromLng);
        final dTo = _distanceMeters(plat.toDouble(), plng.toDouble(), toLat, toLng);
        if (dFrom < 10000 || dTo < 10000) return true;
      }
    }

    return false;
  }

  Future<void> _search() async {
    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();
    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter both origin and destination')));
      return;
    }

    setState(() {
      _loading = true;
      _results = [];
    });

    try {
      final fromLoc = await _geocode(from);
      final toLoc = await _geocode(to);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Query by date only to avoid requiring a composite index; filter seats locally.
    final qs = await FirebaseFirestore.instance.collection('rides').where('date', isEqualTo: dateStr).get();

      final List<Map<String, dynamic>> matches = [];
      for (final doc in qs.docs) {
        final ride = doc.data() as Map<String, dynamic>;
        ride['id'] = doc.id;

        final rideFrom = (ride['from'] ?? ride['start']?['place'] ?? '').toString().toLowerCase();
        final rideTo = (ride['to'] ?? ride['end']?['place'] ?? '').toString().toLowerCase();

        // Seats check (client-side)
        final seats = (ride['seatsAvailable'] ?? ride['availableSeats'] ?? ride['seats'] ?? 0) as int;
        if (seats < _passengers) continue;

        if (rideFrom.contains(from.toLowerCase()) && rideTo.contains(to.toLowerCase())) {
          matches.add(ride);
          continue;
        }

        if (fromLoc != null && toLoc != null) {
          final nearby = _isNearbyRoute(ride, fromLoc.latitude, fromLoc.longitude, toLoc.latitude, toLoc.longitude);
          if (nearby) matches.add(ride);
        }
      }

      setState(() {
        _results = matches;
      });
    } catch (e) {
      // If Firestore requires a composite index, the exception message usually contains a URL.
      String? openUrl;
      if (e is FirebaseException && e.message != null) {
        final msg = e.message!;
        final urlMatch = RegExp(r'https?://\S+').firstMatch(msg);
        if (urlMatch != null) openUrl = urlMatch.group(0);
      }

      if (openUrl != null) {
        // Show a dialog with the link so user can open/create the index in console.
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Search failed - index required'),
              content: const Text('This query requires a Firestore composite index. Open the Firebase console to create the index.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    try {
                      await launchUrlString(openUrl!);
                    } catch (_) {}
                  },
                  child: const Text('Open Index URL'),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e'), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(12)));
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 8)
                  ]),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.circle_outlined),
                    title: TextField(
                        controller: _fromCtrl,
                        decoration: const InputDecoration(
                            hintText: 'Leaving from',
                            border: InputBorder.none)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.circle_outlined),
                    title: TextField(
                        controller: _toCtrl,
                        decoration: const InputDecoration(
                            hintText: 'Going to',
                            border: InputBorder.none)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(DateFormat.yMMMd().format(_selectedDate)),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text('$_passengers Passengers'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _passengers > 1
                              ? () => setState(() => _passengers--)
                              : null),
                      IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () =>
                              setState(() => _passengers++)),
                    ]),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _search,
                      style: ElevatedButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(14))),
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Search'),
                    ),
                  ),
                ],
              ),
            ),
            if (_results.isEmpty && !_loading)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                      'No rides found for the selected criteria. Please try a different date or location.',
                      style: TextStyle(color: Colors.grey[700]))),
            for (final r in _results)
              _SearchResultCard(
                ride: r,
                passengers: _passengers,
              ),
          ],
        ),
      ),
    );
  }
}

// Simple result card used by RideSearchCard when showing search results.
// Kept minimal to match the app's look and to fix missing symbol errors.
class _SearchResultCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final int passengers;

  const _SearchResultCard({Key? key, required this.ride, required this.passengers}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fare = ride['fare']?.toString() ?? 'N/A';
    final from = ride['from'] ?? 'Unknown';
    final to = ride['to'] ?? 'Unknown';
    final date = ride['date'] ?? '';
    final time = ride['time'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$from → $to', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('$date at $time', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₹$fare', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: () {
                    final rideWithId = Map<String, dynamic>.from(ride);
                    if (!rideWithId.containsKey('id')) rideWithId['id'] = rideWithId['id'] ?? '';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PassengerDetailsScreen(numberOfSeats: passengers, ride: rideWithId),
                      ),
                    );
                  },
                  child: const Text('Book'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}