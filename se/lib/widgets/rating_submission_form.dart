import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RatingSubmissionForm extends StatefulWidget {
  final String driverId;
  final String rideId;

  const RatingSubmissionForm({super.key, required this.driverId, required this.rideId});

  @override
  _RatingSubmissionFormState createState() => _RatingSubmissionFormState();
}

class _RatingSubmissionFormState extends State<RatingSubmissionForm> {
  double _rating = 0;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;

  void _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Save the rating to the 'drivers/{driverId}/ratings' subcollection
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .collection('ratings')
          .add({
        'rideId': widget.rideId,
        'rating': _rating,
        'feedback': _reviewController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Update the driver's average rating in the 'drivers' collection
      final driverRef = FirebaseFirestore.instance.collection('drivers').doc(widget.driverId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(driverRef);
        final data = snapshot.data() as Map<String, dynamic>?;

        if (data != null) {
          final oldRating = data['averageRating'] as double? ?? 0.0;
          final ratingCount = data['ratingCount'] as int? ?? 0;

          final newRatingCount = ratingCount + 1;
          final newAverageRating = ((oldRating * ratingCount) + _rating) / newRatingCount;

          transaction.update(driverRef, {
            'averageRating': newAverageRating,
            'ratingCount': newRatingCount,
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating submitted successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting rating: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Ride'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('How was your ride?', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 40,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1.0;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reviewController,
              decoration: const InputDecoration(
                labelText: 'Leave a review (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _isSubmitting
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submitRating,
                    child: const Text('Submit Rating'),
                  ),
          ],
        ),
      ),
    );
  }
}
