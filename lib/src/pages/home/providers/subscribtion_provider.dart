import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SubscriptionsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _subscribedTo = {};

  bool isSubscribed(String targetUid) => _subscribedTo.contains(targetUid);

  String _docId(String follower, String target) => '${follower}_$target';

  Future<void> loadSubscription(String targetUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == targetUid) return;
    final doc = await _firestore
        .collection('subscriptions')
        .doc(_docId(uid, targetUid))
        .get();
    if (doc.exists) {
      _subscribedTo.add(targetUid);
      notifyListeners();
    }
  }

  Future<void> toggleSubscribe(String targetUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == targetUid) return;

    final subRef = _firestore.collection('subscriptions').doc(_docId(uid, targetUid));
    final targetUserRef = _firestore.collection('users').doc(targetUid);
    final wasSubscribed = _subscribedTo.contains(targetUid);

    // Оптимистичное обновление
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
    }
  }
}