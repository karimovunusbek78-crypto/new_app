import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/models/car.dart';

/// "Избранное" — сохранённые из VideoPage авто (кнопка-закладка).
/// Отдельно от "Понравившееся" (FavoritesProvider/сердечко) — разные
/// коллекции, разные провайдеры.
///
/// Хранит ДВЕ вещи в Firestore:
///  1) users/{uid}/savedCars/{carId}   — личный список пользователя
///     (что Я сохранил) — на этом строится страница "Избранное".
///  2) cars/{carId}/savedBy/{uid}      — обратный индекс на самом авто
///     (кто сохранил ЭТО авто) + savesCount на документе авто — на этом
///     строится вкладка "Сохранили" в VideoAnalyticsPage.
class SavedCarsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Set<String> _savedIds = {};
  List<Car> _allCars = [];

  StreamSubscription<QuerySnapshot>? _savedSub;
  StreamSubscription<User?>? _authSub;

  SavedCarsProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint('SAVED: authStateChanges -> uid=${user?.uid}');
      _savedSub?.cancel();
      _savedIds = {};
      if (user != null) _listenToSavedIds(user.uid);
      notifyListeners();
    });
  }

  void _listenToSavedIds(String uid) {
    debugPrint('SAVED: listening for uid=$uid');
    _savedSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('savedCars')
        .snapshots()
        .listen((snap) {
      _savedIds = snap.docs.map((d) => d.id).toSet();
      debugPrint('SAVED: snapshot -> ${_savedIds.length} ids: $_savedIds');
      notifyListeners();
    }, onError: (e) {
      debugPrint('SAVED: ERROR listening: $e');
    });
  }

  /// Вызывается автоматически из ChangeNotifierProxyProvider в main.dart
  /// каждый раз, когда обновляется CarsProvider — так же, как у
  /// FavoritesProvider.updateCars.
  void updateCars(List<Car> cars) {
    _allCars = cars;
    notifyListeners();
  }

  List<Car> get savedCars =>
      _allCars.where((c) => _savedIds.contains(c.id)).toList();

  bool isSaved(String carId) => _savedIds.contains(carId);

  Future<void> toggleSaved(Car car) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('SAVED: toggleSaved called, uid=$uid, car.id=${car.id}');
    if (uid == null) {
      debugPrint('SAVED: ABORT - uid is null, user not logged in');
      return;
    }

    final personalRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('savedCars')
        .doc(car.id);

    final carRef = _firestore.collection('cars').doc(car.id);
    final savedByRef = carRef.collection('savedBy').doc(uid);

    final currentlySaved = _savedIds.contains(car.id);

    if (currentlySaved) {
      _savedIds.remove(car.id);
    } else {
      _savedIds.add(car.id);
    }
    notifyListeners();

    try {
      if (currentlySaved) {
        await personalRef.delete();
        await savedByRef.delete();
        await carRef.update({'savesCount': FieldValue.increment(-1)});
        debugPrint('SAVED: removed ${car.id}');
      } else {
        await personalRef.set({'savedAt': FieldValue.serverTimestamp()});
        await savedByRef.set({'savedAt': FieldValue.serverTimestamp()});
        await carRef.update({'savesCount': FieldValue.increment(1)});
        debugPrint('SAVED: added ${car.id}');
      }
    } catch (e) {
      debugPrint('SAVED: ERROR writing to Firestore: $e');
      if (currentlySaved) {
        _savedIds.add(car.id);
      } else {
        _savedIds.remove(car.id);
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _savedSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}