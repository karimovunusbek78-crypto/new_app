import 'package:flutter/material.dart';
import 'package:new_app/src/pages/autoslon/permission/publish_permission.dart';
import 'package:new_app/src/pages/car_sell/notifier/car_sell_permission_notifier.dart' hide CarSellPermissionNotifier;
import 'package:new_app/src/pages/favorite/providers/favorites_provider.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:provider/provider.dart';
import 'package:new_app/src/authentifications/auth/auth_wrapper.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => AutoslonPermissionNotifier()),
        ChangeNotifierProvider(create: (_) => CarSellPermissionNotifier()),
      ],
      child: ResponsiveSizer(
        builder: (context, orientation, screenType) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}