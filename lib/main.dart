import 'dart:io';
import 'package:aedove/di/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:aedove/pages/home_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'presentation/bloc/app_init/app_init_bloc.dart';
import 'presentation/bloc/app_init/app_init_event.dart';
import 'presentation/bloc/app_init/app_init_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Google Mobile Ads SDK only on supported platforms (Android and iOS)
  if (Platform.isAndroid || Platform.isIOS) {
    await MobileAds.instance.initialize();
  }
  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");
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

  await setupServiceLocator();

  runApp(const AeDoveApp());
}

class AeDoveApp extends StatefulWidget {
  const AeDoveApp({super.key});

  @override
  State<AeDoveApp> createState() => _AeDoveAppState();
}

class _AeDoveAppState extends State<AeDoveApp> {
  late final AppInitBloc _appInitBloc = sl<AppInitBloc>()
    ..add(const AppInitStarted());

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _appInitBloc,
      child: MaterialApp(
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
        home: BlocBuilder<AppInitBloc, AppInitState>(
          builder: (context, state) {
            if (state.status == AppInitStatus.loading ||
                state.status == AppInitStatus.initial) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (state.status == AppInitStatus.failure) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Initialization failed',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.errorMessage ?? 'Unknown error',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            context.read<AppInitBloc>().add(
                              const AppInitStarted(),
                            );
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return const HomePage();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _appInitBloc.close();
    super.dispose();
  }
}
