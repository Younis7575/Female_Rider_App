import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/notifications/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('FemaleRider starting: ${Env.current}');

  // Firebase is optional until google-services.json / GoogleService-Info.plist are added.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    firebaseAvailable = true;
  } catch (e) {
    firebaseAvailable = false;
    debugPrint('Firebase unavailable, push notifications disabled: $e');
  }

  runApp(
    ProviderScope(
      // Repositories surface errors to the UI (with retry buttons) instead of silent auto-retry.
      retry: (retryCount, error) => null,
      child: const FemaleRiderApp(),
    ),
  );
}
