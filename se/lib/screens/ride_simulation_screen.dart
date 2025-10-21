import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'payment_page.dart';
import 'package:campus_ride_sharing_step1/services/api_key.dart';

class NavigationStep {
  final String instruction;
  final LatLng startLocation;
  final LatLng endLocation;
  final int distance;
  final int duration;

  NavigationStep({
    required this.instruction,
    required this.startLocation,
    required this.endLocation,
    required this.distance,
    required this.duration,
  });
}

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
  List<LatLng> _polylineCoordinates = [];
  
  Polyline _traveledRoute = const Polyline(polylineId: PolylineId('traveled_route'));
  Polyline _remainingRoute = const Polyline(polylineId: PolylineId('remaining_route'));

  List<NavigationStep> _navigationSteps = [];
  int _currentStepIndex = 0;
  List<bool> _stepAnnounced = [];

  final FlutterTts _flutterTts = FlutterTts();

  LatLng? _startPoint;
  LatLng? _endPoint;
  LatLng? _currentPosition;

  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isRideCompleted = false;
  BitmapDescriptor _navigationMarkerIcon = BitmapDescriptor.defaultMarker;

  double _speed = 0.0;
  String _eta = '';
  String _driverName = 'Loading...';
  String _vehicleInfo = 'Loading...';
  String _vehiclePhotoUrl = '';

  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initialize();
  }

  Future<void> _initialize() async {
    await _initTts();
    await _setMarkerIcon();
    await _loadInitialData();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _setMarkerIcon() async {
    _navigationMarkerIcon = await _descriptorFromIcon(Icons.navigation, Colors.blue, 120.0);
  }

  Future<void> _loadInitialData() async {
    await _loadDriverInfo();
    await _getCoordinatesAndRoute();
  }

  Future<void> _loadDriverInfo() async {
    try {
      final driverDoc = await FirebaseFirestore.instance.collection('users').doc(widget.driverId).get();
      if (driverDoc.exists) {
        final data = driverDoc.data();
        if (data != null && mounted) {
          setState(() {
            _driverName = data['displayName'] ?? 'Driver';
            _vehicleInfo = "${data['vehicleName'] ?? 'Vehicle'} (${data['vehicleRegNo'] ?? 'N/A'})";
            _vehiclePhotoUrl = data['vehiclePhotoUrl'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading driver info: $e');
      if (mounted) {
        setState(() {
          _driverName = 'Error';
          _vehicleInfo = 'Could not load details';
        });
      }
    }
  }

  Future<BitmapDescriptor> _descriptorFromIcon(IconData iconData, Color color, double size) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: iconData.fontFamily,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);

    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<void> _getCoordinatesAndRoute() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorAndPop('Location permissions are denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showErrorAndPop('Location permissions are permanently denied, we cannot request permissions.');
        return;
      }

      final Position userPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _startPoint = LatLng(userPosition.latitude, userPosition.longitude);

      final endLocations = await locationFromAddress(widget.to);

      if (endLocations.isNotEmpty) {
        _endPoint = LatLng(endLocations.first.latitude, endLocations.first.longitude);
        _currentPosition = _startPoint;

        if (mounted) {
          setState(() {
            _markers.add(Marker(
              markerId: const MarkerId('start'),
              position: _startPoint!,
              infoWindow: const InfoWindow(title: 'Your Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ));
            _markers.add(Marker(
              markerId: const MarkerId('end'),
              position: _endPoint!,
              infoWindow: InfoWindow(title: 'Destination: ${widget.to}'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ));
          });
        }

        await _getRoute();
      } else {
        _showErrorAndPop('Could not find destination location.');
      }
    } catch (e) {
      _showErrorAndPop('Failed to get current location or route: $e');
    }
  }

  Future<void> _getRoute() async {
    if (_startPoint == null || _endPoint == null) return;

    final url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${_startPoint!.latitude},${_startPoint!.longitude}&destination=${_endPoint!.latitude},${_endPoint!.longitude}&key=$googleApiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final routes = jsonResponse['routes'];

      if (routes.isNotEmpty) {
        final route = routes[0];
        final leg = route['legs'][0];
        final steps = leg['steps'] as List;

        List<NavigationStep> navSteps = [];
        List<LatLng> polylineCoords = [];

        for (var step in steps) {
          navSteps.add(NavigationStep(
            instruction: step['html_instructions'],
            startLocation: LatLng(step['start_location']['lat'], step['start_location']['lng']),
            endLocation: LatLng(step['end_location']['lat'], step['end_location']['lng']),
            distance: step['distance']['value'],
            duration: step['duration']['value'],
          ));
          polylineCoords.addAll(_decodePolyline(step['polyline']['points']));
        }

        if (mounted) {
          setState(() {
            _navigationSteps = navSteps;
            _stepAnnounced = List<bool>.filled(navSteps.length, false);
            _polylineCoordinates = polylineCoords;
            _remainingRoute = Polyline(
              polylineId: const PolylineId('remaining_route'),
              points: _polylineCoordinates,
              color: Colors.blue,
              width: 5,
            );
          });
        }
      } else {
        _showErrorAndPop('No route found.');
      }
    } else {
      _showErrorAndPop('Failed to get directions. Status code: ${response.statusCode}');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text.replaceAll(RegExp(r'<[^>]*>'), ''));
  }

  void _startNavigation() {
    if (_polylineCoordinates.isEmpty) return;

    if (mounted) {
      setState(() {
        _markers.add(Marker(
          markerId: const MarkerId('user_location'),
          position: _currentPosition!,
          icon: _navigationMarkerIcon,
          anchor: const Offset(0.5, 0.5),
          flat: true,
        ));
      });
    }

    if (_navigationSteps.isNotEmpty) {
      _speak(_navigationSteps.first.instruction);
    }

    const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _updateCurrentLocation(position);
      },
      onError: (error) {
        print('Location Stream Error: $error');
        _showErrorAndPop("Failed to get location updates. Please ensure GPS is enabled.");
      },
    );
  }

  int _findClosestPolylinePointIndex(LatLng point, List<LatLng> polyline) {
    double minDistance = double.infinity;
    int closestIndex = -1;
    for (int i = 0; i < polyline.length; i++) {
      double distance = _calculateDistance(point, polyline[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  void _updateCurrentLocation(Position position) {
    if (!mounted || _isRideCompleted) return;

    final newPosition = LatLng(position.latitude, position.longitude);

    setState(() {
      _speed = position.speed * 3.6;

      final distance = _calculateDistance(newPosition, _endPoint!);
      if (_speed > 0) {
        final time = distance / (_speed / 3600);
        _eta = '${Duration(seconds: time.toInt()).inMinutes} min';
      } else {
        _eta = 'N/A';
      }

      _currentPosition = newPosition;
      _markers.removeWhere((m) => m.markerId.value == 'user_location');
      _markers.add(Marker(
        markerId: const MarkerId('user_location'),
        position: _currentPosition!,
        icon: _navigationMarkerIcon,
        rotation: position.heading,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      ));

      final closestIndex = _findClosestPolylinePointIndex(newPosition, _polylineCoordinates);
      if (closestIndex != -1) {
        List<LatLng> traveledPoints = _polylineCoordinates.sublist(0, closestIndex + 1);
        traveledPoints.add(newPosition);

        List<LatLng> remainingPoints = [newPosition];
        remainingPoints.addAll(_polylineCoordinates.sublist(closestIndex));

        _traveledRoute = Polyline(
          polylineId: const PolylineId('traveled_route'),
          points: traveledPoints,
          color: Colors.grey,
          width: 5,
        );
        _remainingRoute = Polyline(
          polylineId: const PolylineId('remaining_route'),
          points: remainingPoints,
          color: Colors.blue,
          width: 5,
        );
      }

      if (_currentStepIndex < _navigationSteps.length) {
        final currentStep = _navigationSteps[_currentStepIndex];
        final distanceToStepEnd = _calculateDistance(newPosition, currentStep.endLocation);

        if (distanceToStepEnd < 300 && !_stepAnnounced[_currentStepIndex]) {
          _speak("In ${distanceToStepEnd.round()} meters, ${currentStep.instruction}");
          _stepAnnounced[_currentStepIndex] = true;
        }

        if (distanceToStepEnd < 20) {
          _currentStepIndex++;
          if (_currentStepIndex < _navigationSteps.length) {
            final newStep = _navigationSteps[_currentStepIndex];
            _speak(newStep.instruction);
          }
        }
      }

      _mapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentPosition!,
          zoom: 17,
          tilt: 50.0,
          bearing: position.heading,
        ),
      ));

      if (distance < 0.1) {
        _onRideCompleted();
      }
    });
  }

  double _calculateDistance(LatLng start, LatLng end) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((end.latitude - start.latitude) * p) / 2 + c(start.latitude * p) * c(end.latitude * p) * (1 - c((end.longitude - start.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _onRideCompleted() async {
    _isRideCompleted = true;
    _positionStreamSubscription?.cancel();
    await _flutterTts.stop();
    try {
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({'status': 'completed'});
      final bookingDoc = await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).get();
      final fare = bookingDoc.data()?['fare'];

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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  String _calculateArrivalTime() {
    if (_eta.isEmpty || _eta == 'N/A') return 'N/A';
    try {
      final minutes = int.parse(_eta.split(' ')[0]);
      final arrivalTime = DateTime.now().add(Duration(minutes: minutes));
      return '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Navigation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder(
        future: _initializationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error initializing navigation: ${snapshot.error}"));
          }
          return Stack(
            children: [
              _startPoint == null
                  ? const Center(child: Text("Getting your location..."))
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(target: _startPoint!, zoom: 16),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _startNavigation();
                      },
                      markers: _markers,
                      polylines: Set.of({_traveledRoute, _remainingRoute}),
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),
              _buildNavigationInstruction(),
              _buildRideDetailsSheet(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentPosition != null) {
            _mapController.animateCamera(CameraUpdate.newCameraPosition(
              CameraPosition(target: _currentPosition!, zoom: 17, tilt: 50.0, bearing: 0),
            ));
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildNavigationInstruction() {
    if (_navigationSteps.isEmpty || _currentStepIndex >= _navigationSteps.length) {
      return const SizedBox.shrink();
    }
    final currentStep = _navigationSteps[_currentStepIndex];
    return Positioned(
      top: MediaQuery.of(context).padding.top + kToolbarHeight,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            currentStep.instruction.replaceAll(RegExp(r'<[^>]*>'), ''),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildRideDetailsSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.25,
      minChildSize: 0.15,
      maxChildSize: 0.4,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16.0),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              _buildRideStatsSection(),
              const SizedBox(height: 16),
              _buildDriverInfoSection(),
               const SizedBox(height: 16),
              _buildFinishRideButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriverInfoSection() {
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: _vehiclePhotoUrl.isNotEmpty ? NetworkImage(_vehiclePhotoUrl) : null,
          child: _vehiclePhotoUrl.isEmpty ? const Icon(Icons.person, size: 25, color: Colors.grey) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_driverName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_vehicleInfo, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRideStatsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(Icons.speed, "Speed", '${_speed.toStringAsFixed(1)} km/h'),
        _buildStatItem(Icons.timer, "ETA", _eta),
        _buildStatItem(Icons.schedule, "Arrival", _calculateArrivalTime()),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFinishRideButton() {
    return ElevatedButton.icon(
      onPressed: _onRideCompleted,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      label: const Text('Finish Ride', style: TextStyle(fontSize: 18, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
