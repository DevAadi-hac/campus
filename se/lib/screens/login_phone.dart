import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'otp_verify.dart';
import 'package:fluttertoast/fluttertoast.dart';

class LoginPhoneScreen extends StatefulWidget {
  const LoginPhoneScreen({super.key});
  @override
  State<LoginPhoneScreen> createState() => _LoginPhoneScreenState();
}

class _LoginPhoneScreenState extends State<LoginPhoneScreen> {
  final phoneC = TextEditingController(text: '+91'); // change default country code
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: phoneC,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (include +country)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              if (!mounted) return;
              setState(() => loading = true);
              final err = await auth.signInWithPhone(phoneC.text.trim());
              if (!mounted) return;
              setState(() => loading = false);
              if (err != null) Fluttertoast.showToast(msg: err);
              else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OtpVerifyScreen()));
              }
            },
            child: loading ? const CircularProgressIndicator() : const Text('Send OTP'),
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    phoneC.dispose();
    super.dispose();
  }
}
