
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
  Marker? _riderMarker;
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

    if (role == null) return; // Or handle error

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
      final locationField = role == 'driver' ? 'driverLocation' : 'riderLocation';
      FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        locationField: GeoPoint(currentLocation.latitude!, currentLocation.longitude!),
      });
    });
  }

  void _listenToRideUpdates() {
    FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots().listen((DocumentSnapshot rideSnapshot) {
      if (rideSnapshot.exists) {
        Map<String, dynamic> data = rideSnapshot.data() as Map<String, dynamic>;
        
        if (data.containsKey('driverLocation')) {
          GeoPoint driverLocation = data['driverLocation'];
          _updateMarker('driver', LatLng(driverLocation.latitude, driverLocation.longitude));
        }

        if (data.containsKey('riderLocation')) {
          GeoPoint riderLocation = data['riderLocation'];
          _updateMarker('rider', LatLng(riderLocation.latitude, riderLocation.longitude));
        }
      }
    });
  }

  void _updateMarker(String userType, LatLng position) async {
    final icon = await _bitmapDescriptorFromEmoji(userType == 'driver' ? '🚗' : '🕴️');

    setState(() {
      if (userType == 'driver') {
        _driverMarker = Marker(
          markerId: MarkerId('driver'),
          position: position,
          icon: icon,
          infoWindow: InfoWindow(title: 'Driver'),
        );
      } else {
        _riderMarker = Marker(
          markerId: MarkerId('rider'),
          position: position,
          icon: icon,
          infoWindow: InfoWindow(title: 'Rider'),
        );
      }
    });

    if (!_isInitialCameraPositionSet) {
      _updateCameraPosition();
      if (_driverMarker != null && _riderMarker != null) {
        _isInitialCameraPositionSet = true;
      }
    }
  }

  void _updateCameraPosition() async {
    if (_driverMarker != null && _riderMarker != null) {
      final GoogleMapController controller = await _controller.future;
      
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _driverMarker!.position.latitude < _riderMarker!.position.latitude ? _driverMarker!.position.latitude : _riderMarker!.position.latitude,
          _driverMarker!.position.longitude < _riderMarker!.position.longitude ? _driverMarker!.position.longitude : _riderMarker!.position.longitude,
        ),
        northeast: LatLng(
          _driverMarker!.position.latitude > _riderMarker!.position.latitude ? _driverMarker!.position.latitude : _riderMarker!.position.latitude,
          _driverMarker!.position.longitude > _riderMarker!.position.longitude ? _driverMarker!.position.longitude : _riderMarker!.position.longitude,
        ),
      );

      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    } else if (_driverMarker != null) {
       final GoogleMapController controller = await _controller.future;
       controller.animateCamera(CameraUpdate.newLatLngZoom(_driverMarker!.position, 15));
    } else if (_riderMarker != null) {
       final GoogleMapController controller = await _controller.future;
       controller.animateCamera(CameraUpdate.newLatLngZoom(_riderMarker!.position, 15));
    }
  }

  @override
  Widget build(BuildContext context) {
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
        markers: {_driverMarker, _riderMarker}.where((marker) => marker != null).toSet().cast<Marker>(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _updateCameraPosition,
        child: Icon(Icons.my_location),
      ),
    );
  }
}
