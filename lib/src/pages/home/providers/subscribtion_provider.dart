import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SubscriptionsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _subscribedTo = {};
  final Set<String> _loaded = {};   // чтобы не дёргать Firestore на каждый ребилд виджета
  final Set<String> _pending = {};  // защита от даблтапа / гонки запросов

  bool isSubscribed(String targetUid) => _subscribedTo.contains(targetUid);
  bool isPending(String targetUid) => _pending.contains(targetUid);

  String _docId(String follower, String target) => '${follower}_$target';

  Future<void> loadSubscription(String targetUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == targetUid) return;
    if (_loaded.contains(targetUid)) return;
    _loaded.add(targetUid);
    try {
      final doc = await _firestore
          .collection('subscriptions')
          .doc(_docId(uid, targetUid))
          .get();
      if (doc.exists) {
        _subscribedTo.add(targetUid);
        notifyListeners();
      }
    } catch (_) {
      _loaded.remove(targetUid); // разрешаем повторную попытку при ошибке сети
    }
  }

  Future<void> toggleSubscribe(String targetUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == targetUid) return;
    // Нельзя подписаться второй раз, пока первый запрос ещё летит.
    if (_pending.contains(targetUid)) return;

    final subRef = _firestore.collection('subscriptions').doc(_docId(uid, targetUid));
    final targetUserRef = _firestore.collection('users').doc(targetUid);
    final wasSubscribed = _subscribedTo.contains(targetUid);

    _pending.add(targetUid);
    wasSubscribed ? _subscribedTo.remove(targetUid) : _subscribedTo.add(targetUid);
    notifyListeners();

    try {
      if (wasSubscribed) {
        await subRef.delete();
        await targetUserRef.update({'subscribersCount': FieldValue.increment(-1)});
      } else {
        await subRef.set({
          'followerUid': uid,
          'targetUid': targetUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await targetUserRef.update({'subscribersCount': FieldValue.increment(1)});
      }
    } catch (_) {
      wasSubscribed ? _subscribedTo.add(targetUid) : _subscribedTo.remove(targetUid);
      notifyListeners();
    } finally {
      _pending.remove(targetUid);
      notifyListeners();
    }
  }
}