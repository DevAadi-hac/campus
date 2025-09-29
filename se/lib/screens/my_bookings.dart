import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class MyBookings extends StatefulWidget {
  const MyBookings({super.key});

  @override
  State<MyBookings> createState() => _MyBookingsState();
}

class _MyBookingsState extends State<MyBookings> {
  String? _cancelFeedback;
  bool _isCancelling = false;

  Future<void> _cancelBooking(String bookingId, Map<String, dynamic> booking) async {
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
            Text('Are you sure you want to cancel this booking?'),
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
      await _showCancelFeedbackDialog(bookingId, booking);
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
      // Update booking status to cancelled
      await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelFeedback': _cancelFeedback ?? 'No feedback provided',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Bookings")),
      body: Stack(
        children: [
          StreamBuilder(
            stream: FirebaseFirestore.instance.collection("bookings").snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text("No bookings yet"));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (c, i) {
                  final booking = docs[i].data();
                  final bookingId = docs[i].id;
                  final isConfirmed = booking['status'] == 'confirmed';
                  final isCancelled = booking['status'] == 'cancelled';
                  
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
                                  '${booking['from'] ?? ''} → ${booking['to'] ?? ''}',
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
                                  booking['status']?.toUpperCase() ?? '',
                                  style: TextStyle(
                                    color: isConfirmed ? Colors.green[800] : isCancelled ? Colors.red[800] : Colors.orange[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (booking['fare'] != null)
                            Text('Fare: ₹${booking['fare']}', style: const TextStyle(fontSize: 16)),
                          if (booking['date'] != null && booking['time'] != null)
                            Text('Date: ${booking['date']} | Time: ${booking['time']}', style: const TextStyle(fontSize: 15)),
                          if (booking['costPerKm'] != null)
                            Text('Cost per km: ₹${booking['costPerKm']}', style: const TextStyle(fontSize: 14)),
                          if (booking['vehicleRegNo'] != null)
                            Text('Vehicle Reg No: ${booking['vehicleRegNo']}', style: const TextStyle(fontSize: 14)),
                          if (booking['driverContact'] != null)
                            Text('Driver Contact: ${booking['driverContact']}', style: const TextStyle(fontSize: 14)),
                          if (booking['vehiclePhoto'] != null && booking['vehiclePhoto'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: SizedBox(
                                height: 80,
                                child: Image.network(
                                  booking['vehiclePhoto'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Text('Vehicle photo unavailable'),
                                ),
                              ),
                            ),
                          // Cancel button for confirmed bookings
                          if (isConfirmed) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _cancelBooking(bookingId, booking),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: Icon(Icons.cancel, size: 18),
                                  label: Text('Cancel Booking'),
                                ),
                              ],
                            ),
                          ],
                          // Show cancellation info for cancelled bookings
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
                                      'Booking cancelled. Refund will be processed soon.',
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