import 'package:flutter/material.dart';

/// Глобальный ключ навигатора — нужен, чтобы NotificationBannerHost мог
/// открыть страницу по тапу на баннер, даже находясь ВЫШЕ Navigator'а
/// в дереве виджетов (см. использование `builder:` в MaterialApp).
///
/// Подключение в main.dart:
///   return MaterialApp(
///     navigatorKey: appNavigatorKey,
///     ...
///   );
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();