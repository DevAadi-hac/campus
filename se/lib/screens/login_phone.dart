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
  final aadhaarC = TextEditingController();
  final nameC = TextEditingController();
  final ageC = TextEditingController();
  String? gender;
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(children: [
            TextField(
              controller: phoneC,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (include +country)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: aadhaarC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Aadhaar Number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ageC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: gender,
              hint: const Text('Select Gender'),
              onChanged: (String? newValue) {
                setState(() {
                  gender = newValue;
                });
              },
              items: <String>['Male', 'Female', 'Other']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                if (!mounted) return;
                if (phoneC.text.isEmpty ||
                    aadhaarC.text.isEmpty ||
                    nameC.text.isEmpty ||
                    ageC.text.isEmpty ||
                    gender == null) {
                  Fluttertoast.showToast(msg: 'Please fill all fields');
                  return;
                }
                setState(() => loading = true);
                final err = await auth.signInWithPhone(
                  phoneC.text.trim(),
                  aadhaarC.text.trim(),
                  nameC.text.trim(),
                  int.parse(ageC.text.trim()),
                  gender!,
                );
                if (!mounted) return;
                setState(() => loading = false);
                if (err != null) {
                  Fluttertoast.showToast(msg: err);
                } else {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OtpVerifyScreen()));
                }
              },
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('Send OTP'),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    phoneC.dispose();
    aadhaarC.dispose();
    nameC.dispose();
    ageC.dispose();
    super.dispose();
  }
}
