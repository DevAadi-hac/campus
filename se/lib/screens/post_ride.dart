import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'my_rides.dart';
import 'my_bookings.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class PostRide extends StatefulWidget {
  const PostRide({super.key});

  @override
  State<PostRide> createState() => _PostRideState();
}


class _PostRideState extends State<PostRide> {
  // Helper to update LatLng from Google Places result
  void _setLatLngFromPrediction(Prediction prediction, bool isPickup) {
    final lat = prediction.lat;
    final lng = prediction.lng;
    if (lat != null && lng != null) {
      final latVal = double.tryParse(lat.toString());
      final lngVal = double.tryParse(lng.toString());
      if (latVal != null && lngVal != null) {
        setState(() {
          if (isPickup) {
            _fromLatLng = LatLng(latVal, lngVal);
            fromC.text = prediction.description ?? '';
          } else {
            _toLatLng = LatLng(latVal, lngVal);
            toC.text = prediction.description ?? '';
          }
          _updateFare();
        });
      }
    }
  }
  // Google Places API key for autocomplete
  final String googleApiKey = 'AIzaSyBZtnkBIygYn28_bCYKCHKIwquR3Xz6ZYI';
  List<dynamic> fromSuggestions = [];
  List<dynamic> toSuggestions = [];
  final fromC = TextEditingController();
  final toC = TextEditingController();
  final fareC = TextEditingController();
  final dateC = TextEditingController();
  final timeC = TextEditingController();
  final costPerKmC = TextEditingController();
  final vehicleRegC = TextEditingController();
  final driverContactC = TextEditingController();

  bool loading = false;
  LatLng? _fromLatLng;
  LatLng? _toLatLng;
  GoogleMapController? _mapController;
  bool selectingPickup = true;

  String? costPerKmError;
  String? driverContactError;
  String? aadhaarFileName;
  String? driverPhotoName;
  String? vehiclePhotoName;
  // These would be file paths or URLs after upload in a real app
  dynamic aadhaarFile;
  dynamic driverPhoto;
  dynamic vehiclePhoto;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    dateC.text = DateFormat('yyyy-MM-dd').format(now);
    timeC.text = DateFormat('HH:mm').format(now);
  }

  double _calculateDistanceKm(LatLng a, LatLng b) {
    const double R = 6371; // Earth radius in km
    double dLat = (b.latitude - a.latitude) * 3.141592653589793 / 180.0;
    double dLon = (b.longitude - a.longitude) * 3.141592653589793 / 180.0;
    double lat1 = a.latitude * 3.141592653589793 / 180.0;
    double lat2 = b.latitude * 3.141592653589793 / 180.0;
    double aVal = (sin(dLat / 2) * sin(dLat / 2)) + (sin(dLon / 2) * sin(dLon / 2)) * cos(lat1) * cos(lat2);
    double c = 2 * atan2(sqrt(aVal), sqrt(1 - aVal));
    return R * c;
  }

  void _updateFare() {
    double? costPerKm = double.tryParse(costPerKmC.text);
    if (costPerKmC.text.isEmpty) {
      setState(() => costPerKmError = null);
    } else if (costPerKm == null || costPerKm < 0 || costPerKm > 50) {
      setState(() => costPerKmError = 'Cost per km must be between 0 and 50');
    } else {
      setState(() => costPerKmError = null);
    }
    if (_fromLatLng != null && _toLatLng != null && costPerKm != null && costPerKmError == null) {
      double dist = _calculateDistanceKm(_fromLatLng!, _toLatLng!);
      fareC.text = (dist * costPerKm).toStringAsFixed(2);
    } else {
      fareC.text = '';
    }
  }

  Future<void> _pickFile(String type) async {
    // Use image_picker for all uploads (Aadhaar, driver photo, vehicle photo)
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (type == 'aadhaar') {
          aadhaarFileName = image.name;
          aadhaarFile = image.path;
        } else if (type == 'driverPhoto') {
          driverPhotoName = image.name;
          driverPhoto = image.path;
        } else if (type == 'vehiclePhoto') {
          vehiclePhotoName = image.name;
          vehiclePhoto = image.path;
        }
      });
    }
  }

  Future<void> _postRide() async {
    double? costPerKm = double.tryParse(costPerKmC.text);
    if (_fromLatLng == null || _toLatLng == null || fareC.text.isEmpty || costPerKm == null || costPerKm < 0 || costPerKm > 50) return;
    if (aadhaarFile == null || driverPhoto == null || vehicleRegC.text.isEmpty || driverContactC.text.length != 10 || !RegExp(r'^\d{10}$').hasMatch(driverContactC.text)) {
      driverContactError = 'Enter a valid 10 digit number';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all driver and vehicle details, including a valid 10 digit contact number.')),
      );
      return;
    }
    setState(() => loading = true);
    
    try {
      await FirebaseFirestore.instance.collection("rides").add({
        "from": fromC.text,
        "to": toC.text,
        "fare": fareC.text,
        "date": dateC.text,
        "time": timeC.text,
        "fromLat": _fromLatLng!.latitude,
        "fromLng": _fromLatLng!.longitude,
        "toLat": _toLatLng!.latitude,
        "toLng": _toLatLng!.longitude,
        "costPerKm": costPerKm,
        "driverAadhaar": aadhaarFileName,
        "driverPhoto": driverPhotoName,
        "vehicleRegNo": vehicleRegC.text,
        "driverContact": driverContactC.text,
        "createdAt": FieldValue.serverTimestamp(),
      });
      
      setState(() => loading = false);
      
      // Show success popup
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 8),
                Text('Success!'),
              ],
            ),
            content: Text('Your ride has been posted successfully!'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to previous screen
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting ride: $e')),
        );
      }
    }
  }

  void _onMapTap(LatLng pos) {
    setState(() {
      if (selectingPickup) {
        _fromLatLng = pos;
        fromC.text = '(${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pickup location set at ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        _toLatLng = pos;
        toC.text = '(${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Drop location set at ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      _updateFare();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => child ?? const SizedBox(),
    );
    if (picked != null) {
      dateC.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => child ?? const SizedBox(),
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (picked != null) {
      timeC.text = picked.format(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Post Ride"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rides') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyRides()));
              } else if (value == 'bookings') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyBookings()));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rides', child: Text("My Rides")),
              const PopupMenuItem(value: 'bookings', child: Text("My Bookings")),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                height: MediaQuery.of(context).size.height * 0.5,
                decoration: BoxDecoration(
                  border: Border.all(color: selectingPickup ? Colors.green : Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(21.0, 75.0), zoom: 7,
                    ),
                    onMapCreated: (c) => _mapController = c,
                    markers: {
                      if (_fromLatLng != null)
                        Marker(
                          markerId: const MarkerId('from'), 
                          position: _fromLatLng!, 
                          infoWindow: const InfoWindow(title: 'Pickup'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                        ),
                      if (_toLatLng != null)
                        Marker(
                          markerId: const MarkerId('to'), 
                          position: _toLatLng!, 
                          infoWindow: const InfoWindow(title: 'Drop'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        ),
                    },
                    onTap: _onMapTap,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selectingPickup ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selectingPickup ? Colors.green : Colors.red,
                    width: 1,
                  ),
                ),
                child: Text(
                  selectingPickup 
                    ? '🟢 Tap on map to select PICKUP location' 
                    : '🔴 Tap on map to select DROP location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selectingPickup ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => setState(() => selectingPickup = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectingPickup ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: Icon(selectingPickup ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    label: Text('Select Pickup', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => selectingPickup = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !selectingPickup ? Colors.red : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: Icon(!selectingPickup ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    label: Text('Select Drop', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Clean, always visible pickup and drop fields with Google Places autocomplete and manual entry
              TextField(
                controller: fromC,
                decoration: const InputDecoration(
                  labelText: 'Pickup Location (type manually)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: toC,
                decoration: const InputDecoration(
                  labelText: 'Drop Location (type manually)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 10),
              TextField(
                controller: costPerKmC,
                decoration: InputDecoration(
                  labelText: "Cost per km",
                  errorText: costPerKmError,
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _updateFare(),
              ),
              const SizedBox(height: 10),
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.indigo),
                  title: Text(aadhaarFileName == null ? 'Upload Aadhaar Card' : 'Aadhaar: $aadhaarFileName'),
                  onTap: () => _pickFile('aadhaar'),
                  tileColor: Colors.indigo.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.indigo),
                  title: Text(driverPhotoName == null ? 'Upload Driver Photo' : 'Driver: $driverPhotoName'),
                  onTap: () => _pickFile('driverPhoto'),
                  tileColor: Colors.indigo.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: vehicleRegC,
                decoration: const InputDecoration(labelText: "Vehicle Registration Number"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fareC,
                decoration: const InputDecoration(labelText: "Fare (auto-calculated)"),
                readOnly: true,
              ),
              TextField(
                controller: dateC,
                decoration: const InputDecoration(labelText: "Date"),
                readOnly: true,
                onTap: _pickDate,
              ),
              TextField(
                controller: timeC,
                decoration: const InputDecoration(labelText: "Time"),
                readOnly: true,
                onTap: _pickTime,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: driverContactC,
                decoration: InputDecoration(
                  labelText: "Driver Contact Number",
                  errorText: driverContactError,
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                onChanged: (val) {
                  driverContactError = (val.length == 10 && RegExp(r'^\d{10}$').hasMatch(val)) ? null : (val.isEmpty ? null : 'Enter a valid 10 digit number');
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: loading ? null : _postRide,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Post Ride"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
