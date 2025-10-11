import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'payment_page.dart';
import 'package:campus_ride_sharing_step1/services/api_key.dart';

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
  List<LatLng> _polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();

  LatLng? _startPoint;
  LatLng? _endPoint;
  LatLng? _currentPosition;

  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isRideCompleted = false;
  BitmapDescriptor _carMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

  double _speed = 0.0;
  String _eta = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _getDriverVehiclePhoto();
    await _getCoordinatesAndRoute();
  }

  Future<void> _getDriverVehiclePhoto() async {
    try {
      final driverDoc = await FirebaseFirestore.instance.collection('users').doc(widget.driverId).get();
      if (driverDoc.exists) {
        final data = driverDoc.data();
        if (data != null && data.containsKey('vehiclePhotoUrl')) {
          final imageUrl = data['vehiclePhotoUrl'];
          if (imageUrl != null && imageUrl.isNotEmpty) {
            final Uint8List markerIcon = await _getBytesFromUrl(imageUrl, width: 150);
            if (mounted) {
              setState(() {
                _carMarkerIcon = BitmapDescriptor.fromBytes(markerIcon);
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error loading vehicle photo: $e');
    }
  }

  Future<Uint8List> _getBytesFromUrl(String url, {int width = 100}) async {
    final http.Response response = await http.get(Uri.parse(url));
    final ui.Codec codec = await ui.instantiateImageCodec(response.bodyBytes, targetWidth: width);
    final ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  Future<void> _getCoordinatesAndRoute() async {
    try {
      final startLocations = await locationFromAddress(widget.from);
      final endLocations = await locationFromAddress(widget.to);

      if (startLocations.isNotEmpty && endLocations.isNotEmpty) {
        _startPoint = LatLng(startLocations.first.latitude, startLocations.first.longitude);
        _endPoint = LatLng(endLocations.first.latitude, endLocations.first.longitude);
        _currentPosition = _startPoint;
        await _getRoute();
        if(mounted){
          setState(() {
            // Trigger a rebuild to show the map
          });
        }
      } else {
        _showErrorAndPop('Could not find locations for the given addresses. Please make sure the addresses are correct and specific.');
      }
    } on NoResultFoundException {
      _showErrorAndPop('Could not find any result for the supplied address or coordinates. Please check the addresses and try again.');
    } on PlatformException catch (e) {
      if (e.code == 'IO_ERROR') {
        _showErrorAndPop('Failed to get coordinates due to a network error. This may be due to rate limiting. Please try again later.');
      } else {
        _showErrorAndPop(
            'Failed to get coordinates. Please ensure you have a network connection and that Google Play Services are available on your device. Error: ${e.message}');
      }
    } catch (e) {
      _showErrorAndPop('An unexpected error occurred: $e');
    }
  }

  Future<void> _getRoute() async {
    if (_startPoint == null || _endPoint == null) return;

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: googleApiKey,
      request: PolylineRequest(
          origin: PointLatLng(_startPoint!.latitude, _startPoint!.longitude),
          destination: PointLatLng(_endPoint!.latitude, _endPoint!.longitude),
          mode: TravelMode.driving),
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    } else {
      _showErrorAndPop('Could not get route. Please check your Google Maps API key and network connection. Error: ${result.errorMessage}');
    }
  }

  void _startSimulation() {
    if (_polylineCoordinates.isEmpty) return;

    _polylines.add(Polyline(
      polylineId: const PolylineId('route'),
      points: _polylineCoordinates,
      color: Colors.blue,
      width: 5,
    ));

    _markers.add(Marker(
      markerId: const MarkerId('car'),
      position: _currentPosition!,
      icon: _carMarkerIcon,
    ));

    _positionStreamSubscription = Geolocator.getPositionStream().listen((Position position) {
      print('Position: ${position.latitude}, ${position.longitude}, Speed: ${position.speed}');
      _updateCurrentLocation(position);
    });
  }

  void _updateCurrentLocation(Position position) {
    if (_isRideCompleted) return;

    final newPosition = LatLng(position.latitude, position.longitude);

    setState(() {
      _speed = position.speed * 3.6; // Convert m/s to km/h

      final distance = _calculateDistance(newPosition, _endPoint!);
      if (_speed > 0) {
        final time = distance / (_speed / 3600); // Time in seconds
        final duration = Duration(seconds: time.toInt());
        _eta = '${duration.inMinutes} min';
      } else {
        _eta = 'N/A';
      }

      _currentPosition = newPosition;
      _markers.removeWhere((m) => m.markerId.value == 'car');
      _markers.add(Marker(
        markerId: const MarkerId('car'),
        position: _currentPosition!,
        icon: _carMarkerIcon,
      ));

      _checkOffRoute();

      _mapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentPosition!,
          zoom: 16,
          tilt: 50.0,
        ),
      ));

      if (_calculateDistance(_currentPosition!, _endPoint!) < 0.1) { // 100 meters threshold
        _onRideCompleted();
      }
    });
  }

  void _checkOffRoute() {
    if (_polylineCoordinates.isEmpty) return;

    LatLng nearestPoint = _findNearestPointOnPolyline(_currentPosition!, _polylineCoordinates);
    double distanceToRoute = _calculateDistance(_currentPosition!, nearestPoint);

    _polylines.removeWhere((p) => p.polylineId.value == 'off_route_guidance');

    if (distanceToRoute > 0.05) { // 50 meters threshold
      _polylines.add(Polyline(
        polylineId: const PolylineId('off_route_guidance'),
        points: [_currentPosition!, nearestPoint],
        color: Colors.red,
        width: 3,
        patterns: [PatternItem.dash(10), PatternItem.gap(5)],
      ));
    }
  }

  LatLng _findNearestPointOnPolyline(LatLng point, List<LatLng> polyline) {
    double minDistance = double.infinity;
    LatLng? nearestPoint;

    for (int i = 0; i < polyline.length - 1; i++) {
      LatLng p1 = polyline[i];
      LatLng p2 = polyline[i+1];

      // Simplified projection logic
      double dx = p2.longitude - p1.longitude;
      double dy = p2.latitude - p1.latitude;

      if (dx == 0 && dy == 0) {
        continue;
      }

      double t = ((point.longitude - p1.longitude) * dx + (point.latitude - p1.latitude) * dy) / (dx * dx + dy * dy);

      LatLng currentNearest;
      if (t < 0) {
        currentNearest = p1;
      } else if (t > 1) {
        currentNearest = p2;
      } else {
        currentNearest = LatLng(p1.latitude + t * dy, p1.longitude + t * dx);
      }

      double distance = _calculateDistance(point, currentNearest);
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = currentNearest;
      }
    }
    return nearestPoint ?? polyline.first;
  }


  double _calculateDistance(LatLng start, LatLng end) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((end.latitude - start.latitude) * p) / 2 +
        c(start.latitude * p) * c(end.latitude * p) * (1 - c((end.longitude - start.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _onRideCompleted() async {
    _isRideCompleted = true;
    _positionStreamSubscription?.cancel();
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
    if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride in Progress'),
      ),
      body: Stack(
        children: [
          _startPoint == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _startPoint!,
                    zoom: 14,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _startSimulation();
                  },
                  markers: _markers,
                  polylines: _polylines,
                ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Speed', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_speed.toStringAsFixed(1)} km/h'),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('ETA', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_eta),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}