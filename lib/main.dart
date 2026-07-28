import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:new_app/src/app/my_app.dart';
import 'package:new_app/src/pages/saved/provider/saved_cars_provider.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/pages/home/providers/subscribtion_provider.dart';
import 'package:new_app/src/pages/home/notification/notifications_provider.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:new_app/src/video/controller/main_tab_controller.dart';
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
        ChangeNotifierProvider(create: (_) => CarsProvider()),
        ChangeNotifierProxyProvider<CarsProvider, FavoritesProvider>(
          create: (_) => FavoritesProvider(),
          update: (_, carsProvider, favoritesProvider) =>
              favoritesProvider!..updateCars(carsProvider.cars),
        ),
        ChangeNotifierProxyProvider<CarsProvider, SavedCarsProvider>(
          create: (_) => SavedCarsProvider(),
          update: (_, carsProvider, savedCarsProvider) =>
              savedCarsProvider!..updateCars(carsProvider.cars),
        ),
        ChangeNotifierProvider(create: (_) => SubscriptionsProvider()),
        ChangeNotifierProvider(create: (_) => NavTabController()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}