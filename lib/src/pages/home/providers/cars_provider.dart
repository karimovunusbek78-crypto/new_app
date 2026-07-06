import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/models/car.dart';

class CarsProvider extends ChangeNotifier {
  final List<Car> _cars = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, bool> _likedByMe = {};

  StreamSubscription<QuerySnapshot>? _carsSub;
  bool _loading = true;

  CarsProvider() {
    _listenToCars();
  }

  List<Car> get cars => List.unmodifiable(_cars);
  bool get isLoading => _loading;

  List<Car> get carsWithVideo =>
      _cars.where((c) => c.videoPath != null && c.videoPath!.isNotEmpty).toList();

  List<Car> myCars(String uid) => _cars.where((c) => c.ownerId == uid).toList();

  bool isLikedByMe(String carId) => _likedByMe[carId] ?? false;

  void _listenToCars() {
    _carsSub = _firestore
        .collection('cars')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _cars
        ..clear()
        ..addAll(snapshot.docs.map((doc) => Car.fromFirestore(doc.id, doc.data())));
      _loading = false;
      notifyListeners();
    }, onError: (_) {
      _loading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _carsSub?.cancel();
    super.dispose();
  }

  Future<void> publishCar(Car car) async {
    await _firestore.collection('cars').doc(car.id).set(car.toFirestoreMap());
  }

  Future<void> deleteCar(String carId, {required String reason}) async {
    final carRef = _firestore.collection('cars').doc(carId);
    await carRef.collection('deleteLog').add({
      'reason': reason,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': FirebaseAuth.instance.currentUser?.uid,
    });
    await carRef.delete();
  }

  Future<void> loadLikeState(String carId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await _firestore
        .collection('cars')
        .doc(carId)
        .collection('likedBy')
        .doc(uid)
        .get();
    _likedByMe[carId] = doc.exists;
    notifyListeners();
  }

  Future<void> toggleLike(String carId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final carRef = _firestore.collection('cars').doc(carId);
    final likeRef = carRef.collection('likedBy').doc(uid);
    final currentlyLiked = _likedByMe[carId] ?? false;

    _likedByMe[carId] = !currentlyLiked;
    notifyListeners();

    try {
      if (currentlyLiked) {
        await likeRef.delete();
        await carRef.update({'likesCount': FieldValue.increment(-1)});
      } else {
        await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
        await carRef.update({'likesCount': FieldValue.increment(1)});
      }
    } catch (_) {
      _likedByMe[carId] = currentlyLiked;
      notifyListeners();
    }
  }

  /// [ownerId] — владелец объявления. Если сам автор смотрит своё видео,
  /// просмотр не засчитывается.
  Future<void> incrementView(String carId, String ownerId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid == ownerId) return;

    final carRef = _firestore.collection('cars').doc(carId);
    await carRef.update({'viewsCount': FieldValue.increment(1)}).catchError((_) {});
    await carRef.collection('viewLog').add({
      'viewedAt': FieldValue.serverTimestamp(),
      'viewerUid': uid,
    }).catchError((_) {});
  }

  Future<int> viewsToday(String carId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      final snap = await _firestore
          .collection('cars')
          .doc(carId)
          .collection('viewLog')
          .where('viewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }
}