import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";

import "firebase_options.dart";
import "screens/splash_screen.dart";
import "services/app_state.dart";
import "theme/app_theme.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(TecronApp(appState: AppState()));
}

class TecronApp extends StatelessWidget {
  final AppState appState;

  const TecronApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Tecron",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: SplashScreen(appState: appState),
    );
  }
}
