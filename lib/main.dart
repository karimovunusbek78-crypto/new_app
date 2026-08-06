import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:new_app/src/app/my_app.dart';
import 'package:new_app/src/pages/home/providers/subscribtion_provider.dart'; // ← добавить импорт
import 'package:new_app/src/pages/pages.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => CarsProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionsProvider()), // ← добавить
      ],
      child: const MyApp(),
    ),
  );
}