import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:aedove/pages/home_page.dart';
import 'package:aedove/services/background_service.dart';
import 'package:aedove/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure system UI for edge-to-edge on Android 15+
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Set system UI overlay style for edge-to-edge
  // Note: Setting colors to transparent is handled by enableEdgeToEdge() in MainActivity
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const AeDoveApp());
}

class AeDoveApp extends StatefulWidget {
  const AeDoveApp({super.key});

  @override
  State<AeDoveApp> createState() => _AeDoveAppState();
}

class _AeDoveAppState extends State<AeDoveApp> {
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await BackgroundService.initialize();
      await NotificationService.initialize();
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aedove',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // localizationsDelegates: const [
      //   GlobalMaterialLocalizations.delegate,
      //   GlobalWidgetsLocalizations.delegate,
      //   GlobalCupertinoLocalizations.delegate,
      // ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('es', ''),
        Locale('fr', ''),
        Locale('de', ''),
      ],
      home: const HomePage(),
    );
  }
}
