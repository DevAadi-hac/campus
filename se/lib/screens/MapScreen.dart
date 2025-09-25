import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentPosition;
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    Location location = Location();
    var permission = await location.requestPermission();
    if (permission == PermissionStatus.granted) {
      var pos = await location.getLocation();
      setState(() {
        _currentPosition = LatLng(pos.latitude!, pos.longitude!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 15,
              ),
              myLocationEnabled: true,
              onMapCreated: (c) => _controller = c,
            ),
    );
  }
}
