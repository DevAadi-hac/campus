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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade200, Colors.purple.shade200],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Icon(Icons.directions_car, size: 80, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'Ride Sharing',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: phoneC,
                        labelText: 'Phone (include +country)',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: aadhaarC,
                        labelText: 'Aadhaar Number',
                        icon: Icons.credit_card,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: nameC,
                        labelText: 'Full Name',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: ageC,
                        labelText: 'Age',
                        icon: Icons.cake,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildGenderDropdown(),
                      const SizedBox(height: 24),
                      _buildSendOtpButton(auth),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: gender,
      hint: const Text('Select Gender'),
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(Icons.people, color: Colors.grey.shade600),
      ),
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
    );
  }

  Widget _buildSendOtpButton(AuthService auth) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
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
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        child: loading
            ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white))
            : const Text('Send OTP', style: TextStyle(fontSize: 16)),
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
