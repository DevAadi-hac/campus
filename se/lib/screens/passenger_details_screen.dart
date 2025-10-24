import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/passenger_model.dart';
import '../services/notification_service.dart';
import 'my_bookings.dart';

class PassengerDetailsScreen extends StatefulWidget {
  final int numberOfSeats;
  final Map<String, dynamic> ride;

  const PassengerDetailsScreen({
    super.key,
    required this.numberOfSeats,
    required this.ride,
  });

  @override
  _PassengerDetailsScreenState createState() => _PassengerDetailsScreenState();
}

class _PassengerDetailsScreenState extends State<PassengerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late List<TextEditingController> _nameControllers;
  late List<TextEditingController> _ageControllers;
  late List<String?> _selectedGenders;
  late List<TextEditingController> _aadhaarControllers;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _nameControllers = List.generate(widget.numberOfSeats, (index) => TextEditingController());
    _ageControllers = List.generate(widget.numberOfSeats, (index) => TextEditingController());
    _selectedGenders = List.generate(widget.numberOfSeats, (index) => null);
    _aadhaarControllers = List.generate(widget.numberOfSeats, (index) => TextEditingController());
  }

  @override
  void dispose() {
    for (var i = 0; i < widget.numberOfSeats; i++) {
      _nameControllers[i].dispose();
      _ageControllers[i].dispose();
      _aadhaarControllers[i].dispose();
    }
    super.dispose();
  }

  Future<void> _bookRide() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isBooking = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You need to be logged in to book a ride.')),
          );
          setState(() {
            _isBooking = false;
          });
          return;
        }

        final passengers = <Map<String, dynamic>>[];
        for (var i = 0; i < widget.numberOfSeats; i++) {
          passengers.add({
            'name': _nameControllers[i].text,
            'age': int.parse(_ageControllers[i].text),
            'gender': _selectedGenders[i]!,
            'aadhaarNumber': _aadhaarControllers[i].text,
          });
        }

        final fareValue = num.tryParse(widget.ride['fare'].toString()) ?? 0;
        final totalFare = fareValue * widget.numberOfSeats;

        final existingBookingQuery = await FirebaseFirestore.instance
            .collection('bookings')
            .where('rideId', isEqualTo: widget.ride['id'])
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (existingBookingQuery.docs.isNotEmpty) {
          // Update existing booking
          final bookingDoc = existingBookingQuery.docs.first;
          await FirebaseFirestore.instance.collection('bookings').doc(bookingDoc.id).update({
            'passengers': FieldValue.arrayUnion(passengers),
            'fare': FieldValue.increment(totalFare),
          });
        } else {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final riderName = userDoc.data()?['displayName'] ?? 'Rider';
          final riderContact = user.phoneNumber;
          
          // Generate a 6-digit OTP
          final String otp = (100000 + Random().nextInt(900000)).toString();

          // Create new booking
          final bookingData = {
            'rideId': widget.ride['id'],
            'driverId': widget.ride['driverId'],
            'userId': user.uid,
            'riderName': riderName,
            'riderContact': riderContact,
            'from': widget.ride['from'],
            'to': widget.ride['to'],
            'date': widget.ride['date'],
            'time': widget.ride['time'],
            'fare': totalFare,
            'passengers': passengers,
            'status': 'confirmed',
            'otp': otp, // Add OTP to booking data
            'createdAt': FieldValue.serverTimestamp(),
          };
          await FirebaseFirestore.instance.collection('bookings').add(bookingData);
        }

        // Update seats available in the ride document
        await FirebaseFirestore.instance.collection('rides').doc(widget.ride['id']).update({
          'seatsAvailable': FieldValue.increment(-widget.numberOfSeats),
        });

        // Send booking success notification
        await NotificationService.sendRideNotification(
          userId: user.uid,
          type: 'ride_booked',
          rideData: {
            'from': widget.ride['from'],
            'to': widget.ride['to'],
            'fare': totalFare,
            'date': widget.ride['date'],
            'time': widget.ride['time'],
          },
        );

        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to book ride: $e')),
        );
      } finally {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passenger Details'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: widget.numberOfSeats,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Passenger ${index + 1}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _nameControllers[index],
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a name';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: _ageControllers[index],
                          decoration: const InputDecoration(labelText: 'Age'),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an age';
                            }
                            final age = int.tryParse(value);
                            if (age == null || age <= 0) {
                              return 'Please enter a valid age';
                            }
                            return null;
                          },
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedGenders[index],
                          decoration: const InputDecoration(labelText: 'Gender'),
                          items: ['Male', 'Female', 'Other']
                              .map((gender) => DropdownMenuItem(
                                    value: gender,
                                    child: Text(gender),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedGenders[index] = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a gender';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: _aadhaarControllers[index],
                          decoration: const InputDecoration(labelText: 'Aadhaar Number'),
                          keyboardType: TextInputType.number,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an Aadhaar number';
                            }
                            if (value.length != 12) {
                              return 'Aadhaar number must be 12 digits';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isBooking)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _isBooking ? null : _bookRide,
          child: const Text('Book Ride'),
        ),
      ),
    );
  }
}
