import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> ride;
  const PaymentPage({super.key, required this.ride});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleWallet);

    _openCheckout();
  }

  void _openCheckout() {
    // Ensure fare is a number (int/double), parse if string
    num fareValue;
    if (widget.ride['fare'] is String) {
      fareValue = double.tryParse(widget.ride['fare']) ?? 0;
    } else if (widget.ride['fare'] is num) {
      fareValue = widget.ride['fare'];
    } else {
      fareValue = 0;
    }
    var options = {
      'key': 'rzp_test_RBcLkRDIOCOnml', // 🔑 Replace with your Razorpay Test Key
      'amount': (fareValue * 100).toInt(), // in paise
      'name': 'Campus Ride',
      'description': 'Booking Ride',
      'prefill': {
        'contact': FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
      },
      'theme': {"color": "#0D47A1"}
    };
    _razorpay.open(options);
  }

  void _handleSuccess(PaymentSuccessResponse response) async {
    final user = FirebaseAuth.instance.currentUser!;
    
    try {
      // Add all relevant ride info to booking for display in MyBookings
      await FirebaseFirestore.instance.collection('bookings').add({
        'rideId': widget.ride['id'],
        'riderId': user.uid,
        'driverId': widget.ride['driverId'],
        'fare': widget.ride['fare'],
        'status': 'confirmed',
        'paymentId': response.paymentId,
        'createdAt': FieldValue.serverTimestamp(),
        'from': widget.ride['from'],
        'to': widget.ride['to'],
        'date': widget.ride['date'],
        'time': widget.ride['time'],
        'costPerKm': widget.ride['costPerKm'],
        'vehicleRegNo': widget.ride['vehicleRegNo'],
        'driverContact': widget.ride['driverContact'],
        'vehiclePhoto': widget.ride['vehiclePhoto'],
      });

      // Send booking notification
      NotificationService.sendRideNotification(
        userId: user.uid,
        type: 'ride_booked',
        rideData: {
          'from': widget.ride['from'],
          'to': widget.ride['to'],
          'fare': widget.ride['fare'],
          'date': widget.ride['date'],
          'time': widget.ride['time'],
          'paymentId': response.paymentId,
        },
      );

      if (mounted) {
        // Show success popup
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 8),
                Flexible(child: Text('Booking Confirmed!')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment successful!'),
                SizedBox(height: 8),
                Text('Your ride has been booked successfully.'),
                SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment ID: '),
                    Flexible(child: Text(response.paymentId ?? 'N/A')),
                  ],
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.pushNamedAndRemoveUntil(context, '/myBookings', (route) => false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('View Bookings', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving booking: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _handleError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed: ${response.message}")),
    );
    Navigator.pop(context);
  }

  void _handleWallet(ExternalWalletResponse response) {}

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
