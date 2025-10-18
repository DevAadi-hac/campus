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
      children: passengers.map((passenger) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Icon(Icons.person, color: Theme.of(context).primaryColor, size: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${passenger['name'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Age: ${passenger['age'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600])),
                  Text('Gender: ${passenger['gender'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600])),
                  Text('Aadhaar: ${maskAadhaar(passenger['aadhaarNumber'])}', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _cancelBooking(String bookingId, Map<String, dynamic> bookingData) async {
    final bool? confirmCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Cancel Booking'),
          ],
        ),
        content: const Column(
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
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Booking', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmCancel == true) {
      await _showCancelFeedbackDialog(bookingId, bookingData);
    }
  }

  Future<void> _showCancelFeedbackDialog(String bookingId, Map<String, dynamic> booking) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
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
                const Text(
                  'We\'re sorry to see you go! Please let us know why you\'re canceling:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
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
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processCancellation(bookingId, booking);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
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

      await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelFeedback': _cancelFeedback ?? 'No feedback provided',
      });

      await FirebaseFirestore.instance.collection('rides').doc(rideId).update({
        'seatsAvailable': FieldValue.increment(numberOfCancelledSeats),
      });

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
          title: const Text("My Bookings"),
        ),
        body: const Center(child: Text("Please log in to see your bookings.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Bookings"),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: RideService.streamUserBookings(user.uid),
            builder: (context, userBookingsSnapshot) {
              if (userBookingsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!userBookingsSnapshot.hasData || userBookingsSnapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 20),
                      Text("You have no bookings yet.", style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text("Find a ride and start your journey!", style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                );
              }

              final userBookingDocs = userBookingsSnapshot.data!.docs;
              final rideIds = userBookingDocs.map((doc) => (doc.data() as Map<String, dynamic>)['rideId']).toSet().toList();

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: rideIds.length,
                itemBuilder: (c, i) {
                  final rideId = rideIds[i];
                  final currentUserBookingDoc = userBookingDocs.firstWhere((doc) => (doc.data() as Map<String, dynamic>)['rideId'] == rideId);
                  final currentUserBookingId = currentUserBookingDoc.id;
                  final currentUserBookingData = currentUserBookingDoc.data() as Map<String, dynamic>;

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

                      final status = currentUserBookingData['status'] ?? 'unknown';
                      switch (status) {
                        case 'completed':
                          return _buildCompletedBookingCard(currentUserBookingId, currentUserBookingData, rideData);
                        case 'cancelled':
                          return _buildCancelledBookingCard(currentUserBookingData, rideData);
                        default:
                          return _buildActiveBookingCard(currentUserBookingId, currentUserBookingData, rideData, rideId);
                      }
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

  Widget _buildActiveBookingCard(String bookingId, Map<String, dynamic> bookingData, Map<String, dynamic> rideData, String rideId) {
    final seatsAvailable = rideData['seatsAvailable'] ?? 0;
    final isConfirmed = bookingData['status'] == 'confirmed';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rideData['vehiclePhoto'] != null && rideData['vehiclePhoto'].toString().isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              child: Image.network(
                rideData['vehiclePhoto'],
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.directions_car, color: Theme.of(context).primaryColor, size: 32),
                  title: Text(
                    '${rideData['from'] ?? ''} → ${rideData['to'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  trailing: _buildStatusChip(bookingData['status']),
                ),
                const Divider(),
                _buildInfoRow(Icons.calendar_today, '${rideData['date']} at ${rideData['time']}'),
                _buildInfoRow(Icons.currency_rupee, '${bookingData['fare']}'),
                _buildInfoRow(
                  Icons.airline_seat_recline_normal,
                  seatsAvailable > 0 ? 'Seats Available: $seatsAvailable' : 'Ride is Full',
                  color: seatsAvailable > 0 ? Colors.green.shade700 : Colors.red.shade700,
                ),
                const Divider(),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('bookings').where('rideId', isEqualTo: rideId).snapshots(),
                  builder: (context, allBookingsSnapshot) {
                    if (!allBookingsSnapshot.hasData) return const SizedBox.shrink();
                    final allPassengers = allBookingsSnapshot.data!.docs.expand((doc) => (doc.data() as Map<String, dynamic>)['passengers'] as List).toList();
                    return ExpansionTile(
                      title: const Text('View Passengers', style: TextStyle(fontWeight: FontWeight.w600)),
                      children: [_buildPassengerDetails(allPassengers)],
                    );
                  },
                ),
              ],
            ),
          ),
          if (isConfirmed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                alignment: WrapAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(rideId: rideId, otherUserId: rideData['driverId'], otherUserName: 'Driver'))),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Chat'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RideSimulationScreen(from: rideData['from'], to: rideData['to'], rideId: rideId, driverId: rideData['driverId'], bookingId: bookingId))),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Simulate'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _cancelBooking(bookingId, bookingData),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedBookingCard(String bookingId, Map<String, dynamic> bookingData, Map<String, dynamic> rideData) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle, color: Colors.green, size: 32),
              title: Text(
                '${rideData['from'] ?? ''} → ${rideData['to'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              trailing: _buildStatusChip('completed'),
            ),
            const Divider(height: 24),
            if (bookingData['rating'] != null) ...[
              const Text('Your Feedback:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Rating: ', style: TextStyle(color: Colors.grey[600])),
                  for (int i = 0; i < (bookingData['rating'] as num).toInt(); i++)
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                  for (int i = 0; i < 5 - (bookingData['rating'] as num).toInt(); i++)
                    const Icon(Icons.star_border, color: Colors.amber, size: 20),
                ],
              ),
              if (bookingData['feedback'] != null && bookingData['feedback'].isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Feedback: ${bookingData['feedback']}', style: TextStyle(color: Colors.grey[600])),
              ]
            ]
            else
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FeedbackPage(driverId: rideData['driverId'], bookingId: bookingId))),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Provide Feedback'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Theme.of(context).primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                tooltip: 'Delete Booking',
                onPressed: () => _deleteBooking(bookingId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledBookingCard(Map<String, dynamic> bookingData, Map<String, dynamic> rideData) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      color: Colors.grey[200],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cancel, color: Colors.red[700], size: 32),
              title: Text(
                '${rideData['from'] ?? ''} → ${rideData['to'] ?? ''}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[600], decoration: TextDecoration.lineThrough),
              ),
              trailing: _buildStatusChip('cancelled'),
            ),
            const Divider(),
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
                  const SizedBox(width: 8),
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
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 15, color: color)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    String text;
    switch (status) {
      case 'confirmed':
        color = Colors.green;
        text = 'CONFIRMED';
        break;
      case 'cancelled':
        color = Colors.red;
        text = 'CANCELLED';
        break;
      case 'completed':
        color = Colors.blue;
        text = 'COMPLETED';
        break;
      default:
        color = Colors.orange;
        text = status?.toUpperCase() ?? 'PENDING';
    }
    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
