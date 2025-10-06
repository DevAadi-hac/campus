import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'ride_simulation_screen.dart';
import 'feedback_page.dart';

class PaymentPage extends StatefulWidget {
  final String? bookingId;
  final String? rideId;
  final String? driverId;
  final double? fare;
  final Map<String, dynamic>? ride;

  const PaymentPage({
    super.key,
    this.bookingId,
    this.rideId,
    this.driverId,
    this.fare,
    this.ride,
  });

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
    num fareValue;
    if (widget.fare != null) {
      fareValue = widget.fare!;
    } else if (widget.ride != null && widget.ride!['fare'] is String) {
      fareValue = double.tryParse(widget.ride!['fare']) ?? 0;
    } else if (widget.ride != null && widget.ride!['fare'] is num) {
      fareValue = widget.ride!['fare'];
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
    if (widget.bookingId != null) {
      // Post-ride payment
      await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).update({
        'status': 'completed',
        'paymentId': response.paymentId,
      });

      if (widget.driverId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FeedbackPage(
              driverId: widget.driverId!,
              bookingId: widget.bookingId!,
            ),
          ),
        );
      }
    } else {
      // Pre-ride booking payment
      final user = FirebaseAuth.instance.currentUser!;
      final auth = Provider.of<AuthService>(context, listen: false);
      final profile = auth.profile;

      try {
        // Add all relevant ride info to booking for display in MyBookings
        final newBooking = await FirebaseFirestore.instance.collection('bookings').add({
          'rideId': widget.ride!['id'],
          'userId': user.uid,
          'riderName': profile?['displayName'] ?? 'N/A',
          'riderContact': user.phoneNumber ?? 'N/A',
          'driverId': widget.ride!['driverId'],
          'fare': widget.ride!['fare'],
          'status': 'confirmed',
          'paymentId': response.paymentId,
          'createdAt': FieldValue.serverTimestamp(),
          'from': widget.ride!['from'],
          'to': widget.ride!['to'],
          'date': widget.ride!['date'],
          'time': widget.ride!['time'],
          'costPerKm': widget.ride!['costPerKm'],
          'vehicleRegNo': widget.ride!['vehicleRegNo'],
          'driverContact': widget.ride!['driverContact'],
          'vehiclePhoto': widget.ride!['vehiclePhoto'],
        });

        // Send booking notification
        NotificationService.sendRideNotification(
          userId: user.uid,
          type: 'ride_booked',
          rideData: {
            'from': widget.ride!['from'],
            'to': widget.ride!['to'],
            'fare': widget.ride!['fare'],
            'date': widget.ride!['date'],
            'time': widget.ride!['time'],
            'paymentId': response.paymentId,
          },
        );

        if (mounted) {
          final from = widget.ride!['from'] as String?;
          final to = widget.ride!['to'] as String?;
          final driverId = widget.ride!['driverId'] as String?;

          if (from == null || to == null || driverId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Ride data is incomplete. Cannot start simulation.')),
            );
            Navigator.pop(context);
            return;
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RideSimulationScreen(
                from: from,
                to: to,
                rideId: widget.ride!['id'],
                driverId: driverId,
                bookingId: newBooking.id,
              ),
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