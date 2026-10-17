import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Отправка уведомлений — просто пишет документ в
/// users/{toUid}/notifications/{auto-id}. Никакой связи с провайдером не
/// требуется, поэтому эти методы можно звать из любого места: toggleLike,
/// отправка комментария/ответа, toggleSubscribe и т.д.
///
/// Все методы САМИ защищены от уведомления самого себя (например лайк
/// собственного объявления) — см. `_send`.
class NotificationSender {
  NotificationSender._();

  static final _db = FirebaseFirestore.instance;

  // Небольшой локальный кэш аватарок отправителя, чтобы не делать лишний
  // Firestore-запрос на каждое действие (лайк/комментарий) подряд.
  static String? _cachedAvatarUid;
  static String? _cachedAvatarUrl;

  static Future<void> _send({
    required String toUid,
    required String type,
    required String fromUid,
    required String fromName,
    String? fromAvatarUrl,
    String? carId,
    String? carName,
    String? commentId,
    String? text,
  }) async {
    // Не уведомляем самого себя (лайк/комментарий/подписка на своё же).
    if (toUid.isEmpty || toUid == fromUid) return;
    try {
      await _db
          .collection('users')
          .doc(toUid)
          .collection('notifications')
          .add({
        'type': type,
        'fromUid': fromUid,
        'fromName': fromName,
        'fromAvatarUrl': fromAvatarUrl,
        'carId': carId,
        'carName': carName,
        'commentId': commentId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (_) {
      // Не критично — если отправка уведомления не удалась, основное
      // действие (лайк/комментарий/подписка) всё равно должно было
      // пройти успешно, поэтому просто молча пропускаем.
    }
  }

  static String _displayName(User user) {
    final n = user.displayName;
    return (n != null && n.trim().isNotEmpty) ? n.trim() : 'Пользователь';
  }

  static Future<String?> _myAvatarUrl(String uid) async {
    if (_cachedAvatarUid == uid) return _cachedAvatarUrl;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final url = (doc.data()?['avatarUrl'] as String?) ?? '';
      _cachedAvatarUid = uid;
      _cachedAvatarUrl = url.isNotEmpty ? url : null;
      return _cachedAvatarUrl;
    } catch (_) {
      return null;
    }
  }

  /// Кто-то лайкнул объявление [carId], принадлежащее [toUid].
  static Future<void> sendLike({
    required String toUid,
    required String carId,
    String? carName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _send(
      toUid: toUid,
      type: 'like',
      fromUid: user.uid,
      fromName: _displayName(user),
      fromAvatarUrl: await _myAvatarUrl(user.uid),
      carId: carId,
      carName: carName,
    );
  }

  /// Кто-то оставил НОВЫЙ комментарий верхнего уровня под объявлением
  /// [carId] владельца [toUid] (сам владелец, если он и есть комментатор,
  /// уведомление не получит — см. `_send`).
  static Future<void> sendComment({
    required String toUid,
    required String carId,
    String? carName,
    required String commentId,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _send(
      toUid: toUid,
      type: 'comment',
      fromUid: user.uid,
      fromName: _displayName(user),
      fromAvatarUrl: await _myAvatarUrl(user.uid),
      carId: carId,
      carName: carName,
      commentId: commentId,
      text: text,
    );
  }

  /// Кто-то ОТВЕТИЛ на комментарий/ответ пользователя [toUid] (автора
  /// исходного комментария/ответа) под объявлением [carId].
  static Future<void> sendReply({
    required String toUid,
    required String carId,
    String? carName,
    required String commentId,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _send(
      toUid: toUid,
      type: 'reply',
      fromUid: user.uid,
      fromName: _displayName(user),
      fromAvatarUrl: await _myAvatarUrl(user.uid),
      carId: carId,
      carName: carName,
      commentId: commentId,
      text: text,
    );
  }

  /// Кто-то подписался на пользователя [toUid].
  static Future<void> sendSubscribe({required String toUid}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _send(
      toUid: toUid,
      type: 'subscribe',
      fromUid: user.uid,
      fromName: _displayName(user),
      fromAvatarUrl: await _myAvatarUrl(user.uid),
    );
  }
}