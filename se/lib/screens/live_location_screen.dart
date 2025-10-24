import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

import 'dart:ui' as ui;

class LiveLocationScreen extends StatefulWidget {
  final String rideId;

  const LiveLocationScreen({Key? key, required this.rideId}) : super(key: key);

  @override
  _LiveLocationScreenState createState() => _LiveLocationScreenState();
}

Future<BitmapDescriptor> _bitmapDescriptorFromEmoji(String emoji) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  final TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
  painter.text = TextSpan(
    text: emoji,
    style: TextStyle(fontSize: 100, color: Colors.black), // Adjust size and color as needed
  );
  painter.layout();
  painter.paint(canvas, Offset.zero);
  final img = await pictureRecorder.endRecording().toImage(painter.width.toInt(), painter.height.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Location _locationService = Location();
  StreamSubscription<LocationData>? _locationSubscription;

  Marker? _driverMarker;
  Map<String, Marker> _riderMarkers = {};
  bool _isInitialCameraPositionSet = false;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _listenToRideUpdates();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final role = authService.profile?['role'];
    final userId = authService.user?.uid;

    if (role == null || userId == null) return; // Or handle error

    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await _locationService.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationService.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationSubscription = _locationService.onLocationChanged.listen((LocationData currentLocation) {
      if (role == 'driver') {
        FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
          'driverLocation': GeoPoint(currentLocation.latitude!, currentLocation.longitude!),
        });
      } else {
        FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
          'passengerLocations.$userId': GeoPoint(currentLocation.latitude!, currentLocation.longitude!),
        });
      }
    });
  }

  void _listenToRideUpdates() {
    FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots().listen((DocumentSnapshot rideSnapshot) {
      if (rideSnapshot.exists) {
        Map<String, dynamic> data = rideSnapshot.data() as Map<String, dynamic>;
        
        if (data.containsKey('driverLocation')) {
          GeoPoint driverLocation = data['driverLocation'];
          _updateMarker('driver', 'driver', LatLng(driverLocation.latitude, driverLocation.longitude));
        }

        if (data.containsKey('passengerLocations')) {
          Map<String, dynamic> passengerLocations = data['passengerLocations'];
          int riderCount = 1;
          passengerLocations.forEach((key, value) {
            GeoPoint riderLocation = value;
            _updateMarker('rider_$key', 'rider$riderCount', LatLng(riderLocation.latitude, riderLocation.longitude));
            riderCount++;
          });
        }
      }
    });
  }

  void _updateMarker(String markerId, String title, LatLng position) async {
    final icon = await _bitmapDescriptorFromEmoji(title.startsWith('driver') ? '🚗' : '🕴️');

    setState(() {
      if (title.startsWith('driver')) {
        _driverMarker = Marker(
          markerId: MarkerId(markerId),
          position: position,
          icon: icon,
          infoWindow: InfoWindow(title: 'Driver'),
        );
      } else {
        _riderMarkers[markerId] = Marker(
          markerId: MarkerId(markerId),
          position: position,
          icon: icon,
          infoWindow: InfoWindow(title: title),
        );
      }
    });

    if (!_isInitialCameraPositionSet) {
      _updateCameraPosition();
      if (_driverMarker != null && _riderMarkers.isNotEmpty) {
        _isInitialCameraPositionSet = true;
      }
    }
  }

  void _updateCameraPosition() async {
    final GoogleMapController controller = await _controller.future;
    
    List<Marker> allMarkers = [];
    if(_driverMarker != null) allMarkers.add(_driverMarker!);
    allMarkers.addAll(_riderMarkers.values);

    if (allMarkers.length > 1) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          allMarkers.map((m) => m.position.latitude).reduce((a, b) => a < b ? a : b),
          allMarkers.map((m) => m.position.longitude).reduce((a, b) => a < b ? a : b),
        ),
        northeast: LatLng(
          allMarkers.map((m) => m.position.latitude).reduce((a, b) => a > b ? a : b),
          allMarkers.map((m) => m.position.longitude).reduce((a, b) => a > b ? a : b),
        ),
      );

      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    } else if (allMarkers.length == 1) {
       controller.animateCamera(CameraUpdate.newLatLngZoom(allMarkers.first.position, 15));
    }
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {_driverMarker, ..._riderMarkers.values}.where((marker) => marker != null).toSet().cast<Marker>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Ride Location'),
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: CameraPosition(
          target: LatLng(21.1702, 72.8311), // Default to Surat
          zoom: 12,
        ),
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        markers: markers,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _updateCameraPosition,
        child: Icon(Icons.my_location),
      ),
    );
  }
}