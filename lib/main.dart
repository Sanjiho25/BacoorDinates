import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:untitled/screens/HomePage.dart';
import 'package:untitled/screens/LoginPage.dart';
import 'package:untitled/screens/language_selection_screen.dart';
import 'package:untitled/screens/NotificationsPage.dart';
import 'package:untitled/screens/animated_splash_screen.dart';
import 'l10n/app_localizations.dart';

import 'components/StyleGuide.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/camera_screen.dart';
import 'services/notification_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      // Web/desktop Firebase configuration is not set up in firebase_options.dart.
      // Skip initialization here until those platforms are configured.
      debugPrint('Skipping Firebase initialization on unsupported platform: '
          '${kIsWeb ? 'web' : defaultTargetPlatform}');
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return MaterialApp(
      title: 'BacoTrip',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme,
      home: const AnimatedSplashScreen(nextScreen: AuthWrapper()),
      locale: languageProvider.currentLocale,
      routes: {
        '/styleguide': (context) => const StyleGuide(),
        '/camera': (context) => const ARViewerScreen(),
        '/language': (context) => const LanguageSelectionScreen(),
        '/notifications': (context) => const NotificationsPage(),
      },
      // Add localization support
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isAuthenticated) {
      return const HomePage();
    } else {
      return const LoginPage();
    }
  }
}
