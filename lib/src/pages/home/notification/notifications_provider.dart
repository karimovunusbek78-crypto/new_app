import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:new_app/src/pages/home/notification/app_notification.dart';


/// Живой стрим уведомлений текущего пользователя.
///
/// Использование:
///  1. Зарегистрировать в MultiProvider (main.dart):
///       ChangeNotifierProvider(create: (_) => NotificationsProvider()),
///  2. При входе пользователя (например в MainNavBar.initState или сразу
///     после успешного логина) вызвать:
///       context.read<NotificationsProvider>().start(uid);
///  3. При выходе — context.read<NotificationsProvider>().stop();
///
/// [hasUnread] — используется колокольчиком (NotificationBell), чтобы
/// стать синим при непрочитанных уведомлениях.
/// [incoming] — сюда попадает КАЖДОЕ новое уведомление, пришедшее уже
/// ПОСЛЕ первой загрузки (не исторические) — на него подписан
/// NotificationBannerHost, чтобы показать слайд-карточку сверху экрана.
class NotificationsProvider extends ChangeNotifier {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;
  bool _initialLoadDone = false;

  List<AppNotification> _items = [];
  List<AppNotification> get items => _items;

  int get unreadCount => _items.where((n) => !n.read).length;
  bool get hasUnread => unreadCount > 0;

  AppNotification? _incoming;
  AppNotification? get incoming => _incoming;

  /// Начинает слушать users/{uid}/notifications. Безопасно вызывать
  /// повторно с тем же uid — подписка не пересоздаётся.
  void start(String uid) {
    if (_uid == uid && _sub != null) return;
    _uid = uid;
    _initialLoadDone = false;
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(_onSnapshot, onError: (_) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _items = [];
    _incoming = null;
    _initialLoadDone = false;
    notifyListeners();
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    _items = snap.docs.map((d) => AppNotification.fromDoc(d)).toList();

    // Баннер сверху экрана показываем ТОЛЬКО для уведомлений, пришедших
    // ПОСЛЕ первой загрузки списка — иначе при каждом открытии приложения
    // всплывал бы баннер по всем старым уведомлениям сразу.
    if (_initialLoadDone) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _incoming = AppNotification.fromDoc(change.doc);
        }
      }
    } else {
      _initialLoadDone = true;
    }
    notifyListeners();
  }

  /// Вызывается баннером после показа/автоскрытия — чтобы то же самое
  /// уведомление не всплыло повторно при следующем notifyListeners().
  void clearIncoming() {
    if (_incoming == null) return;
    _incoming = null;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    final unread = _items.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    final col =
        FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications');
    for (final n in unread) {
      batch.update(col.doc(n.id), {'read': true});
    }
    try {
      await batch.commit();
    } catch (_) {}
  }

  Future<void> markRead(String id) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(id)
          .update({'read': true});
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}