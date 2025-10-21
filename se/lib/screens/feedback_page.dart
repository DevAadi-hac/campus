import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackPage extends StatefulWidget {
  final String driverId;
  final String bookingId;
  const FeedbackPage({super.key, required this.driverId, required this.bookingId});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  double _rating = 3.0;
  final _feedbackController = TextEditingController();

  void _submitFeedback() async {
    await FirebaseFirestore.instance
        .collection("drivers")
        .doc(widget.driverId)
        .collection("ratings")
        .add({"rating": _rating, "feedback": _feedbackController.text, "createdAt": FieldValue.serverTimestamp()});

    await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).update({
      'status': 'completed',
      'rating': _rating,
      'feedback': _feedbackController.text,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Feedback Submitted!")),
    );

    Navigator.pop(context); // Go back to home
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Feedback")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Rate your ride:", style: TextStyle(fontSize: 20)),
          const SizedBox(height: 20),
          Slider(
            value: _rating,
            min: 1,
            max: 5,
            divisions: 4,
            label: _rating.toString(),
            onChanged: (value) {
              setState(() {
                _rating = value;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Feedback',
              ),
              maxLines: 3,
            ),
          ),
          ElevatedButton(
            onPressed: _submitFeedback,
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }
}