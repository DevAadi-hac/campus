import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final otpC = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: otpC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Enter OTP'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              setState(() => loading = true);
              final err = await auth.verifyOTPAndSignIn(otpC.text.trim());
              setState(() => loading = false);
              if (err != null) {
                Fluttertoast.showToast(msg: err);
              } else {
                Navigator.pop(context); // success -> go back or push home
              }
            },
            child: loading ? const CircularProgressIndicator() : const Text('Verify'),
          ),
        ]),
      ),
    );
  }
}
