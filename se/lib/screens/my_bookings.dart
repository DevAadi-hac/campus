import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../services/ride_service.dart';
import '../widgets/rating_submission_form.dart';
import 'chat_screen.dart';
import 'ride_simulation_screen.dart';
import 'feedback_page.dart';

class MyBookings extends StatefulWidget {
  const MyBookings({super.key});

  @override
  State<MyBookings> createState() => _MyBookingsState();
}

class _MyBookingsState extends State<MyBookings> {
  String? _cancelFeedback;
  bool _isCancelling = false;

  Widget _buildPassengerDetails(List<dynamic> passengers) {
    String maskAadhaar(String? aadhaar) {
      if (aadhaar != null && aadhaar.length >= 4) {
        return '********${aadhaar.substring(aadhaar.length - 4)}';
      }
      return aadhaar ?? 'N/A';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('All Passengers:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...passengers.map((passenger) {
          return Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${passenger['name'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Age: ${passenger['age'] ?? 'N/A'}'),
                  const SizedBox(height: 4),
                  Text('Gender: ${passenger['gender'] ?? 'N/A'}'),
                  const SizedBox(height: 4),
                  Text('Aadhaar: ${maskAadhaar(passenger['aadhaarNumber'])}'),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Future<void> _cancelBooking(String bookingId, Map<String, dynamic> bookingData) async {
    // Show confirmation dialog
    final bool? confirmCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Cancel Booking'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel your booking for this ride?'),
            SizedBox(height: 8),
            Text('Your ride will be cancelled and money will be refunded soon.',
                 style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Cancel Booking', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmCancel == true) {
      // Show sad emoji feedback dialog
      await _showCancelFeedbackDialog(bookingId, bookingData);
    }
  }

  Future<void> _showCancelFeedbackDialog(String bookingId, Map<String, dynamic> booking) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('😢', style: TextStyle(fontSize: 28)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Why are you canceling?',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'We\'re sorry to see you go! Please let us know why you\'re canceling:',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Tell us why you\'re canceling...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                  onChanged: (value) {
                    setDialogState(() {
                      _cancelFeedback = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processCancellation(bookingId, booking);
              },
              child: Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processCancellation(bookingId, booking);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processCancellation(String bookingId, Map<String, dynamic> booking) async {
    setState(() {
      _isCancelling = true;
    });

    try {
      final rideId = booking['rideId'];
      final numberOfCancelledSeats = (booking['passengers'] as List).length;

      // Update booking status to cancelled
      await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelFeedback': _cancelFeedback ?? 'No feedback provided',
      });

      // Add back the seats to the ride
      await FirebaseFirestore.instance.collection('rides').doc(rideId).update({
        'seatsAvailable': FieldValue.increment(numberOfCancelledSeats),
      });

      // Send cancellation notification
      if (FirebaseAuth.instance.currentUser != null) {
        NotificationService.sendRideNotification(
          userId: FirebaseAuth.instance.currentUser!.uid,
          type: 'ride_cancelled',
          rideData: {
            'from': booking['from'],
            'to': booking['to'],
            'fare': booking['fare'],
            'date': booking['date'],
            'time': booking['time'],
            'cancelFeedback': _cancelFeedback,
          },
        );
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking cancelled successfully! Refund will be processed soon.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling booking: $e')),
        );
      }
    } finally {
      setState(() {
        _isCancelling = false;
      });
    }
  }

  Future<void> _deleteBooking(String bookingId) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Booking'),
        content: const Text('Are you sure you want to delete this booking history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('bookings').doc(bookingId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking deleted successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting booking: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text("My Bookings"),
        ),
        body: const Center(child: Text("Please log in to see your bookings.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text("My Bookings"),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: RideService.streamUserBookings(user.uid),
            builder: (context, userBookingsSnapshot) {
              if (!userBookingsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final userBookingDocs = userBookingsSnapshot.data!.docs;
              if (userBookingDocs.isEmpty) {
                return const Center(child: Text("No bookings yet"));
              }

              final rideIds = userBookingDocs.map((doc) => (doc.data() as Map<String,dynamic>)['rideId']).toSet().toList();

              return ListView.builder(
                itemCount: rideIds.length,
                itemBuilder: (c, i) {
                  final rideId = rideIds[i];

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('rides').doc(rideId).snapshots(),
                    builder: (context, rideSnapshot) {
                      if (!rideSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final rideData = rideSnapshot.data!.data() as Map<String, dynamic>?;
                      if (rideData == null) {
                        return const SizedBox.shrink(); // Ride data not found
                      }
                      final seatsAvailable = rideData['seatsAvailable'] ?? 0;

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('bookings').where('rideId', isEqualTo: rideId).snapshots(),
                        builder: (context, allBookingsSnapshot) {
                          if (!allBookingsSnapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final allBookingDocs = allBookingsSnapshot.data!.docs;
                          final allPassengers = allBookingDocs.expand((doc) => (doc.data() as Map<String, dynamic>)['passengers'] as List).toList();
                          
                          QueryDocumentSnapshot<Object?>? currentUserBookingDoc;
                          for (var doc in allBookingDocs) {
                            if ((doc.data() as Map<String, dynamic>)['userId'] == user.uid) {
                              currentUserBookingDoc = doc;
                              break;
                            }
                          }

                          if (currentUserBookingDoc == null) {
                            return const SizedBox.shrink();
                          }
                          final currentUserBookingId = currentUserBookingDoc.id;
                          final currentUserBookingData = currentUserBookingDoc.data() as Map<String, dynamic>;

                          final isConfirmed = currentUserBookingData['status'] == 'confirmed';
                          final isCancelled = currentUserBookingData['status'] == 'cancelled';
                          final isCompleted = currentUserBookingData['status'] == 'completed';

                          if (isCompleted) {
                            return Card(
                              margin: const EdgeInsets.all(12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            '${rideData['from'] ?? ''} → ${rideData['to'] ?? ''}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'COMPLETED',
                                            style: TextStyle(
                                              color: Colors.blue[800],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    _buildPassengerDetails(allPassengers),
                                    if (currentUserBookingData['rating'] != null) ...[
                                      Text('Your Feedback:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text('Rating: ', style: TextStyle(color: Colors.grey[600])),
                                          for (int i = 0; i < (currentUserBookingData['rating'] as num).toInt(); i++)
                                            const Icon(Icons.star, color: Colors.amber, size: 20),
                                          for (int i = 0; i < 5 - (currentUserBookingData['rating'] as num).toInt(); i++)
                                            const Icon(Icons.star_border, color: Colors.amber, size: 20),
                                        ],
                                      ),
                                      if (currentUserBookingData['feedback'] != null && currentUserBookingData['feedback'].isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text('Feedback: ${currentUserBookingData['feedback']}', style: TextStyle(color: Colors.grey[600])),
                                      ]
                                    ] else ...[
                                      Center(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => FeedbackPage(
                                                  driverId: rideData['driverId'],
                                                  bookingId: currentUserBookingId,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.edit, size: 18),
                                          label: const Text('Provide Feedback'),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: Theme.of(context).primaryColor),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                          ),
                                        ),
                                      )
                                    ],
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                                        tooltip: 'Delete Booking',
                                        onPressed: () => _deleteBooking(currentUserBookingId),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Card(
                            margin: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.directions_car, color: Colors.indigo, size: 32),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '${rideData['from'] ?? ''} → ${rideData['to'] ?? ''}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isConfirmed ? Colors.green[100] : isCancelled ? Colors.red[100] : Colors.orange[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          currentUserBookingData['status']?.toUpperCase() ?? '',
                                          style: TextStyle(
                                            color: isConfirmed ? Colors.green[800] : isCancelled ? Colors.red[800] : Colors.orange[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Fare: ₹${currentUserBookingData['fare']}', style: const TextStyle(fontSize: 16)),
                                  Text('Date: ${rideData['date']} | Time: ${rideData['time']}', style: const TextStyle(fontSize: 15)),
                                  Text(
                                    seatsAvailable > 0 ? 'Seats Available: $seatsAvailable' : 'Seats: Full',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: seatsAvailable > 0 ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildPassengerDetails(allPassengers),
                                  if (rideData['vehiclePhoto'] != null && rideData['vehiclePhoto'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Center(
                                        child: SizedBox(
                                          height: 150,
                                          child: Image.network(
                                            rideData['vehiclePhoto'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(), // Don't show error text
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (isConfirmed)
                                        Flexible(
                                          child: Wrap(
                                            alignment: WrapAlignment.end,
                                            spacing: 8.0,
                                            runSpacing: 8.0,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => ChatScreen(
                                                        rideId: rideId,
                                                        otherUserId: rideData['driverId'],
                                                        otherUserName: 'Driver',
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                ),
                                                icon: const Icon(Icons.chat, size: 18),
                                                label: const Text('Chat with Driver'),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => RideSimulationScreen(
                                                        from: rideData['from'],
                                                        to: rideData['to'],
                                                        rideId: rideId,
                                                        driverId: rideData['driverId'],
                                                        bookingId: currentUserBookingId,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue,
                                                  foregroundColor: Colors.white,
                                                ),
                                                icon: const Icon(Icons.play_arrow, size: 18),
                                                label: const Text('Simulate Ride'),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () => _cancelBooking(currentUserBookingId, currentUserBookingData),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                icon: const Icon(Icons.cancel, size: 18),
                                                label: const Text('Cancel Booking'),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (isCancelled) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.red[200]!),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info, color: Colors.red[600], size: 20),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'You have cancelled your booking for this ride.',
                                              style: TextStyle(color: Colors.red[800], fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          if (_isCancelling)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}