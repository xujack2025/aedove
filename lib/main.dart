import 'package:flutter/material.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:aedove/pages/home_page.dart';
import 'package:aedove/services/background_service.dart';
import 'package:aedove/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CPSShareApp());
}

class CPSShareApp extends StatefulWidget {
  const CPSShareApp({super.key});

  @override
  State<CPSShareApp> createState() => _CPSShareAppState();
}

class _CPSShareAppState extends State<CPSShareApp> {
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
      title: 'CP Share',
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
