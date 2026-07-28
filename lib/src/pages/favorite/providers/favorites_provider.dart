// lib/providers/favorites_provider.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/models/car.dart';

class FavoritesProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Set<String> _favoriteIds = {};
  List<Car> _allCars = [];

  StreamSubscription<QuerySnapshot>? _favoritesSub;
  StreamSubscription<User?>? _authSub;

  FavoritesProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint('FAVORITES: authStateChanges -> uid=${user?.uid}');
      _favoritesSub?.cancel();
      _favoriteIds = {};
      if (user != null) _listenToFavoriteIds(user.uid);
      notifyListeners();
    });
  }

  void _listenToFavoriteIds(String uid) {
    debugPrint('FAVORITES: listening for uid=$uid');
    _favoritesSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .listen((snap) {
      _favoriteIds = snap.docs.map((d) => d.id).toSet();
      debugPrint('FAVORITES: snapshot -> ${_favoriteIds.length} ids: $_favoriteIds');
      notifyListeners();
    }, onError: (e) {
      debugPrint('FAVORITES: ERROR listening: $e');
    });
  }

  void updateCars(List<Car> cars) {
    _allCars = cars;
    debugPrint('FAVORITES: updateCars -> ${cars.length} cars, sample ids: ${cars.take(5).map((c) => c.id).toList()}');
    notifyListeners();
  }

  List<Car> get favorites {
    final result = _allCars.where((c) => _favoriteIds.contains(c.id)).toList();
    debugPrint('FAVORITES: getter -> favIds=$_favoriteIds allCars=${_allCars.length} result=${result.length}');
    return result;
  }

  bool isFavorite(Car car) => _favoriteIds.contains(car.id);

  Future<void> toggleFavorite(Car car) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('FAVORITES: toggleFavorite called, uid=$uid, car.id=${car.id}');
    if (uid == null) {
      debugPrint('FAVORITES: ABORT - uid is null, user not logged in');
      return;
    }

    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(car.id);

    final currentlyFav = _favoriteIds.contains(car.id);

    if (currentlyFav) {
      _favoriteIds.remove(car.id);
    } else {
      _favoriteIds.add(car.id);
    }
    notifyListeners();

    try {
      if (currentlyFav) {
        await ref.delete();
        debugPrint('FAVORITES: deleted ${car.id} from Firestore');
      } else {
        await ref.set({'addedAt': FieldValue.serverTimestamp()});
        debugPrint('FAVORITES: wrote ${car.id} to Firestore at users/$uid/favorites/${car.id}');
      }
    } catch (e) {
      debugPrint('FAVORITES: ERROR writing to Firestore: $e');
      if (currentlyFav) {
        _favoriteIds.add(car.id);
      } else {
        _favoriteIds.remove(car.id);
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _favoritesSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}