import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/auth_wrapper.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase, handling potential duplicate initialization
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Ex: $e');
    if (e is FirebaseException) {
      debugPrint('Code: ${e.code}');
      if (e.code == 'duplicate-app' || e.code == 'core/duplicate-app') {
        debugPrint('Ignoring duplicate app error');
        // Don't return - continue to runApp()
      } else {
        rethrow;
      }
    } else {
      rethrow;
    }
  }
  
  runApp(const GrowLensApp());
}

class GrowLensApp extends StatelessWidget {
  const GrowLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrowLens',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}
