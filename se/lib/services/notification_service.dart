import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Set up message handlers (only if initialization successful)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      
      // Request permission and save token in background
      Future.delayed(Duration(seconds: 2), () {
        _requestPermission();
        _saveFCMToken();
      });
      
    } catch (e) {
      print('Error initializing notifications: $e');
      // Continue app initialization even if notifications fail
    }
  }

  static void _requestPermission() {
    _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    ).then((settings) {
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('User granted provisional permission');
      } else {
        print('User declined or has not accepted permission');
      }
    }).catchError((e) {
      print('Error requesting permission: $e');
    });
  }

  static void _saveFCMToken() {
    _firebaseMessaging.getToken().then((token) {
      if (token != null && FirebaseAuth.instance.currentUser != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({'fcmToken': token})
            .then((_) {
          print('FCM Token saved: $token');
        }).catchError((e) {
          print('Error saving FCM token: $e');
        });
      }
    }).catchError((e) {
      print('Error getting FCM token: $e');
    });
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');
    
    // Show local notification
    await _showLocalNotification(
      title: message.notification?.title ?? 'Campus Ride',
      body: message.notification?.body ?? 'You have a new notification',
      payload: message.data.toString(),
    );
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Received background message: ${message.messageId}');
    // Handle background message (navigate to specific screen, etc.)
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'campus_ride_channel',
      'Campus Ride Notifications',
      channelDescription: 'Notifications for Campus Ride app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Handle notification tap (navigate to specific screen)
  }

  // Send notification to specific user
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        String? fcmToken = userData['fcmToken'];
        if (fcmToken != null) {
          // In a real app, you would send this via your backend.
          // The following is a placeholder and does not send a real push notification.
          // It only logs to the console.
          print('Simulating sending push notification to $userId with title: $title and body: $body');
          
          // For demo purposes, we'll just show a local notification
          await _showLocalNotification(
            title: title,
            body: body,
            payload: data?.toString(),
          );
        }
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Send ride-related notifications
  static Future<void> sendRideNotification({
    required String userId,
    required String type, // 'ride_posted', 'ride_booked', 'ride_cancelled', 'driver_arrived'
    required Map<String, dynamic> rideData,
  }) async {
    String title = '';
    String body = '';

    switch (type) {
      case 'ride_posted':
        title = '🚗 Ride Posted Successfully!';
        body = 'Your ride from ${rideData['from']} to ${rideData['to']} has been posted.';
        break;
      case 'ride_booked':
        title = '✅ Ride Booked!';
        body = 'You have successfully booked a ride for ₹${rideData['fare']}.';
        break;
      case 'ride_cancelled':
        title = '❌ Ride Cancelled';
        body = 'Your ride has been cancelled. Refund will be processed soon.';
        break;
      case 'driver_arrived':
        title = '🚗 Driver Arrived!';
        body = 'Your driver has arrived at the pickup location.';
        break;
      default:
        title = 'Campus Ride';
        body = 'You have a new notification.';
    }

    await sendNotificationToUser(
      userId: userId,
      title: title,
      body: body,
      data: rideData,
    );
  }
}
