import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_app/src/app/app_theme.dart';
import 'package:new_app/src/pages/home/notification/app_navigator.dart';
import 'package:new_app/src/pages/home/notification/notification_banner_host.dart';
import 'package:new_app/src/pages/autoslon/permission/publish_permission.dart';
import 'package:provider/provider.dart';
import 'package:new_app/src/authentifications/auth/auth_wrapper.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AutoslonPermissionNotifier()),
        ChangeNotifierProvider(create: (_) => CarSellPermissionNotifier()),
      ],
      child: ResponsiveSizer(
        builder: (context, orientation, screenType) {
          return MaterialApp(
            title: 'Gravitas Auto',
            navigatorKey: appNavigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            // Тёмные иконки статус-бара по умолчанию для всех экранов:
            // иначе после ленты видео (светлые иконки) открытые поверх
            // светлые страницы оставались с белым, нечитаемым статус-баром.
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark,
              child: NotificationBannerHost(child: child!),
            ),
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}
