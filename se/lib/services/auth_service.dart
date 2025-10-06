import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _fa = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  User? get user => _fa.currentUser;
  Map<String, dynamic>? profile;
  bool isLoading = true;
  String? _verificationId;

  // Temp store for user details during verification
  String? _aadhaar;
  String? _name;
  int? _age;
  String? _gender;

  AuthService() {
    init();
  }

  void init() {
    _fa.authStateChanges().listen((u) async {
      if (u != null) {
        final doc = await _fs.collection('users').doc(u.uid).get();
        profile = doc.exists ? doc.data() : null;
      } else {
        profile = null;
      }
      isLoading = false;
      notifyListeners();
    });
  }

  Future<String?> signInWithPhone(
    String phone,
    String aadhaar,
    String name,
    int age,
    String gender,
  ) async {
    isLoading = true;
    notifyListeners();
    try {
      // Store user details temporarily
      _aadhaar = aadhaar;
      _name = name;
      _age = age;
      _gender = gender;

      await _fa.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (cred) async {
          await _fa.signInWithCredential(cred);
        },
        verificationFailed: (e) {
          isLoading = false;
          notifyListeners();
        },
        codeSent: (verId, _) {
          _verificationId = verId;
          isLoading = false;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (verId) {
          _verificationId = verId;
          isLoading = false;
          notifyListeners();
        },
        timeout: const Duration(seconds: 60),
      );
      return null;
    } on FirebaseAuthException catch (e) {
      isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> verifyOTPAndSignIn(String smsCode) async {
    if (_verificationId == null) return 'No verification ID';
    isLoading = true;
    notifyListeners();
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      final result = await _fa.signInWithCredential(cred);
      final u = result.user!;

      final docRef = _fs.collection('users').doc(u.uid);

      // Prepare user data
      Map<String, dynamic> userData = {
        'phone': u.phoneNumber,
        'displayName': _name ?? u.displayName ?? '',
        'aadhaar': _aadhaar,
        'age': _age,
        'gender': _gender,
      };

      // Check if the document exists
      final doc = await docRef.get();
      if (!doc.exists) {
        // If it's a new user, add createdAt and role
        userData['createdAt'] = FieldValue.serverTimestamp();
        userData['role'] = null;
      }

      // Use set with merge to create or update the document
      await docRef.set(userData, SetOptions(merge: true));
      isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> setRole(String role, {String? name}) async {
    if (user == null) return 'No user';
    isLoading = true;
    notifyListeners();
    try {
      final docRef = _fs.collection('users').doc(user!.uid);
      await docRef.set({
        'role': role,
        'displayName': name ?? profile?['displayName'] ?? user!.phoneNumber ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      profile = (await docRef.get()).data();
      isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _fa.signOut();
    profile = null;
    notifyListeners();
  }
}
