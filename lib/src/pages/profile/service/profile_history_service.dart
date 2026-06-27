import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Keeps `users/{uid}` as the current profile snapshot, and additionally
/// writes every change — name, email, phone, telegram, avatar/photo,
/// anything passed in — into `users/{uid}/history/{autoId}`.
///
/// The `history` subcollection is append-only: nothing in it is ever
/// updated or deleted, so old values never disappear. The main document
/// just stays fast to read for "what are this user's current details".
class ProfileHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// [uid] - the user whose profile changed.
  /// [changes] - the full set of current field values you're saving, e.g.
  ///   {
  ///     'name': 'Ivan Petrov',
  ///     'email': 'ivan@mail.com',
  ///     'phone': '+996 600 809',
  ///     'telegram': '@ivan',
  ///     'avatarUrl': 'https://...',
  ///   }
  /// Only the fields that actually differ from what's currently stored
  /// get written to history — unchanged fields aren't logged again.
  Future<void> saveProfile(String uid, Map<String, dynamic> changes) async {
    final docRef = _firestore.collection('users').doc(uid);;

    // Read the current snapshot first so we know what actually changed.
    final snapshot = await docRef.get();
    final previous = snapshot.data() ?? {};

    final changeLog = <String, dynamic>{};
    changes.forEach((field, newValue) {
      final oldValue = previous[field];
      if (oldValue != newValue) {
        changeLog[field] = {'from': oldValue, 'to': newValue};
      }
    });

    final batch = _firestore.batch();

    // 1) Update the current-state document (what the rest of the app reads).
    batch.set(
      docRef,
      {
        ...changes,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 2) If anything actually changed, permanently log it. This document
    // is never edited again — each future change just adds a new one.
    if (changeLog.isNotEmpty) {
      final historyRef = docRef.collection('history').doc();
      batch.set(historyRef, {
        'changes': changeLog,
        'changedBy': FirebaseAuth.instance.currentUser?.uid,
        'changedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Stream of every past change for this user, most recent first.
  /// Use this to render an "activity log" / "edit history" screen.
  Stream<List<Map<String, dynamic>>> watchHistory(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('history')
        .orderBy('changedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }
}