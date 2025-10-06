import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_page.dart';

class RideSimulationScreen extends StatefulWidget {
  final String from;
  final String to;
  final String rideId;
  final String driverId;
  final String bookingId;

  const RideSimulationScreen({
    super.key,
    required this.from,
    required this.to,
    required this.rideId,
    required this.driverId,
    required this.bookingId,
  });

  @override
  _RideSimulationScreenState createState() => _RideSimulationScreenState();
}

class _RideSimulationScreenState extends State<RideSimulationScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  LatLng? _startPoint;
  LatLng? _endPoint;

  Timer? _timer;
  int _step = 0;
  final int _totalSteps = 15;

  @override
  void initState() {
    super.initState();
    _getCoordinatesAndStartSimulation();
  }

  Future<void> _getCoordinatesAndStartSimulation() async {
    try {
      final startLocations = await locationFromAddress(widget.from);
      final endLocations = await locationFromAddress(widget.to);

      if (startLocations.isNotEmpty && endLocations.isNotEmpty) {
        setState(() {
          _startPoint = LatLng(startLocations.first.latitude, startLocations.first.longitude);
          _endPoint = LatLng(endLocations.first.latitude, endLocations.first.longitude);
        });
        _startSimulation();
      } else {
        _showErrorAndPop('Could not find locations for the given addresses.');
      }
    } on PlatformException catch (e) {
      _showErrorAndPop(
          'Failed to get coordinates. Please ensure you have a network connection and that Google Play Services are available on your device. Error: ${e.message}');
    } catch (e) {
      _showErrorAndPop('An unexpected error occurred: $e');
    }
  }

  void _startSimulation() {
    if (_startPoint == null || _endPoint == null) return;

    _polylines.add(Polyline(
      polylineId: const PolylineId('route'),
      points: [_startPoint!, _endPoint!],
      color: Colors.blue,
      width: 5,
    ));

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_step >= _totalSteps) {
        timer.cancel();
        _onRideCompleted();
        return;
      }

      setState(() {
        _step++;
        final progress = _step / _totalSteps;
        final newPosition = LatLng(
          _startPoint!.latitude + (_endPoint!.latitude - _startPoint!.latitude) * progress,
          _startPoint!.longitude + (_endPoint!.longitude - _startPoint!.longitude) * progress,
        );
        _markers.clear();
        _markers.add(Marker(
          markerId: const MarkerId('car'),
          position: newPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ));
      });
    });
  }

  Future<void> _onRideCompleted() async {
    try {
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'status': 'completed',
      });

      final bookingDoc = await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).get();
      final bookingData = bookingDoc.data();
      final fare = bookingData?['fare'];

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentPage(
              bookingId: widget.bookingId,
              rideId: widget.rideId,
              driverId: widget.driverId,
              fare: fare is num ? fare.toDouble() : double.tryParse(fare.toString()) ?? 0.0,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorAndPop('Error updating ride status: $e');
    }
  }

  void _showErrorAndPop(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride in Progress'),
      ),
      body: _startPoint == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _startPoint!,
                zoom: 14,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: _markers,
              polylines: _polylines,
            ),
    );
  }
}
