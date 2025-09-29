import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'providers/theme_provider.dart';
import 'screens/login_phone.dart';
import 'screens/role_select.dart';
import 'screens/driver_home.dart';
import 'screens/rider_home.dart';
import 'screens/my_bookings.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (if you generated firebase_options.dart you can pass options)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    // Initialization might already be done elsewhere or options missing — log and continue.
    debugPrint('Firebase.initializeApp() error: $e\n$st');
  }
  
  // Initialize notifications
  try {
    await NotificationService.initialize();
    NotificationService.setNavigatorKey(navigatorKey);
  } catch (e, st) {
    debugPrint('Notification initialization error: $e\n$st');
    // Continue app initialization even if notifications fail
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..init()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Campus Ride',
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routes: {
        '/myBookings': (context) => const MyBookings(),
      },
      home: Builder(builder: (context) {
        if (auth.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (auth.user == null) {
          return const LoginPhoneScreen();
        }
        final role = auth.profile?['role'];
        if (role == null) {
          return const RoleSelectScreen();
        }
        if (role == 'driver') return const DriverHome();
        return const RiderHome();
      }),
    );
  }
}
