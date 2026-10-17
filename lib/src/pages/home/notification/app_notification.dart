import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Тип уведомления. Хранится в Firestore строкой (см. [AppNotification.typeKey]).
enum AppNotificationType { like, comment, reply, subscribe }

AppNotificationType _typeFromString(String? raw) {
  switch (raw) {
    case 'like':
      return AppNotificationType.like;
    case 'comment':
      return AppNotificationType.comment;
    case 'reply':
      return AppNotificationType.reply;
    case 'subscribe':
      return AppNotificationType.subscribe;
    default:
      return AppNotificationType.like;
  }
}

String _typeToString(AppNotificationType t) {
  switch (t) {
    case AppNotificationType.like:
      return 'like';
    case AppNotificationType.comment:
      return 'comment';
    case AppNotificationType.reply:
      return 'reply';
    case AppNotificationType.subscribe:
      return 'subscribe';
  }
}

/// Одно уведомление пользователя.
/// Хранится в users/{uid}/notifications/{id}.
class AppNotification {
  final String id;
  final AppNotificationType type;
  final String fromUid;
  final String fromName;
  final String? fromAvatarUrl;
  final String? carId;
  final String? carName;
  final String? commentId;
  final String? text; // превью текста комментария/ответа
  final DateTime? createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromName,
    this.fromAvatarUrl,
    this.carId,
    this.carName,
    this.commentId,
    this.text,
    this.createdAt,
    this.read = false,
  });

  String get typeKey => _typeToString(type);

  factory AppNotification.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['createdAt'];
    return AppNotification(
      id: doc.id,
      type: _typeFromString(data['type'] as String?),
      fromUid: (data['fromUid'] as String?) ?? '',
      fromName: (data['fromName'] as String?) ?? 'Пользователь',
      fromAvatarUrl: data['fromAvatarUrl'] as String?,
      carId: data['carId'] as String?,
      carName: data['carName'] as String?,
      commentId: data['commentId'] as String?,
      text: data['text'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : null,
      read: (data['read'] as bool?) ?? false,
    );
  }

  /// Готовый текст для карточки/списка уведомлений — уже с именем автора.
  String get message {
    switch (type) {
      case AppNotificationType.like:
        return carName != null && carName!.isNotEmpty
            ? '$fromName оценил(а) ваше объявление «$carName»'
            : '$fromName оценил(а) ваше объявление';
      case AppNotificationType.comment:
        return carName != null && carName!.isNotEmpty
            ? '$fromName прокомментировал(а) «$carName»'
            : '$fromName оставил(а) комментарий';
      case AppNotificationType.reply:
        return '$fromName ответил(а) на ваш комментарий';
      case AppNotificationType.subscribe:
        return '$fromName подписался(-ась) на вас';
    }
  }

  IconData get icon {
    switch (type) {
      case AppNotificationType.like:
        return Icons.favorite_rounded;
      case AppNotificationType.comment:
        return Icons.mode_comment_rounded;
      case AppNotificationType.reply:
        return Icons.reply_rounded;
      case AppNotificationType.subscribe:
        return Icons.person_add_rounded;
    }
  }

  Color get accentColor {
    switch (type) {
      case AppNotificationType.like:
        return const Color(0xFFFF3B30);
      case AppNotificationType.comment:
      case AppNotificationType.reply:
        return const Color(0xFF4DA6FF);
      case AppNotificationType.subscribe:
        return const Color(0xFF34C759);
    }
  }
}