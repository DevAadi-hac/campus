import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'feedback_page.dart';

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

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/myBookings', (route) => false);
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
