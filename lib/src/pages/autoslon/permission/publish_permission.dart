import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Which kind of publishing a permission applies to.
enum PublishType { autoslon, carsell }

/// UI state derived from the user's permission document.
enum PublishPermissionState {
  loading, // still reading from Firestore
  none, //    no request yet -> show the "contact us" screen
  waiting, // request sent, waiting for admin -> show the "waiting" screen
  granted, // approved (one-time) -> show the publish page / form
}

/// Low-level Firestore access for one-time publish permissions.
///
/// Firestore layout (one document per user):
///
///   publish_permissions/{uid} {
///     autoslonRequested : bool,
///     autoslonGranted   : bool,   // <- admin flips this to true to approve
///     carsellRequested  : bool,
///     carsellGranted    : bool,   // <- admin flips this to true to approve
///     updatedAt         : Timestamp,
///   }
///
/// The collection is created automatically the first time a user taps a
/// contact button (see [request]).
class PublishPermissions {
  PublishPermissions._();

  static const String collection = 'publish_permissions';

  static String requestedField(PublishType t) =>
      t == PublishType.autoslon ? 'autoslonRequested' : 'carsellRequested';

  static String grantedField(PublishType t) =>
      t == PublishType.autoslon ? 'autoslonGranted' : 'carsellGranted';

  static DocumentReference<Map<String, dynamic>>? _doc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection(collection).doc(uid);
  }

  /// Live stream of the current user's permission document.
  static Stream<DocumentSnapshot<Map<String, dynamic>>>? stream() =>
      _doc()?.snapshots();

  /// Mark that the user has asked for permission (after tapping a contact
  /// button). Creates the document if it does not exist yet, so the admin can
  /// find it in the Firestore console by the user's UID.
  static Future<void> request(PublishType t) async {
    final ref = _doc();
    if (ref == null) return;
    await ref.set({
      requestedField(t): true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Consume the one-time permission after a successful publish.
  /// Clears both the granted and requested flags so the user has to ask again
  /// for the next listing.
  static Future<void> consume(PublishType t) async {
    final ref = _doc();
    if (ref == null) return;
    await ref.set({
      grantedField(t): false,
      requestedField(t): false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/// Base notifier: listens to the permission document in real time and exposes
/// a simple [PublishPermissionState] to the UI.
abstract class _PublishPermissionNotifier extends ChangeNotifier {
  PublishType get type;

  PublishPermissionState _state = PublishPermissionState.loading;
  PublishPermissionState get state => _state;

  bool get isGranted => _state == PublishPermissionState.granted;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  /// Begin listening. Safe to call more than once.
  void start() {
    final stream = PublishPermissions.stream();
    if (stream == null) {
      _set(PublishPermissionState.none);
      return;
    }
    _sub?.cancel();
    _sub = stream.listen(
      (snap) {
        final data = snap.data();
        final granted = data?[PublishPermissions.grantedField(type)] == true;
        final requested =
            data?[PublishPermissions.requestedField(type)] == true;

        if (granted) {
          _set(PublishPermissionState.granted);
        } else if (requested) {
          _set(PublishPermissionState.waiting);
        } else {
          _set(PublishPermissionState.none);
        }
      },
      onError: (_) => _set(PublishPermissionState.none),
    );
  }

  /// Backwards-compatible alias for [start].
  Future<void> loadPermission() async => start();

  /// Called when the user taps a contact button. Optimistically moves to the
  /// waiting state, then records the request in Firestore.
  Future<void> requestPermission() async {
    if (_state == PublishPermissionState.none ||
        _state == PublishPermissionState.loading) {
      _set(PublishPermissionState.waiting);
    }
    try {
      await PublishPermissions.request(type);
    } catch (_) {
      // The live listener will reconcile with the real value.
    }
  }

  /// Consume the permission after publishing.
  Future<void> consume() async {
    try {
      await PublishPermissions.consume(type);
    } catch (_) {}
    _set(PublishPermissionState.none);
  }

  void _set(PublishPermissionState s) {
    if (_state == s) return;
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class AutoslonPermissionNotifier extends _PublishPermissionNotifier {
  @override
  PublishType get type => PublishType.autoslon;
}

class CarSellPermissionNotifier extends _PublishPermissionNotifier {
  @override
  PublishType get type => PublishType.carsell;
}

/// Shared confirmation dialog shown right before publishing.
/// Returns `true` only if the user confirmed.
Future<bool> showPublishConfirmDialog(BuildContext context) async {
  const accentBlue = Color(0xFF5B4FD9);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'Всё готово?',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF111111),
        ),
      ),
      content: const Text(
        'Проверьте, что вы заполнили все поля и добавили фото.\n\n'
        'После публикации разрешение будет использовано — для следующего '
        'объявления его нужно будет получить заново.',
        style: TextStyle(color: Color(0xFF6A6A70), height: 1.4),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Назад',
            style: TextStyle(
              color: Color(0xFF9A9AA0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 10, 10, 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Опубликовать',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}