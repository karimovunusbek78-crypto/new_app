import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/notification/notification_sender.dart';

class CarsProvider extends ChangeNotifier {
  final List<Car> _cars = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ЕДИНЫЙ источник правды для лайков. Заполняется целиком одним живым
  // collectionGroup-запросом при логине, а не по одной карточке за раз —
  // поэтому лайк, поставленный в любом месте приложения (лента, карточка
  // на Home, страница деталей), мгновенно виден везде через notifyListeners().
  final Set<String> _likedCarIds = {};

  StreamSubscription<QuerySnapshot>? _carsSub;
  StreamSubscription<QuerySnapshot>? _likedSub;
  StreamSubscription<User?>? _authSub;
  bool _loading = true;

  CarsProvider() {
    _listenToCars();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _likedSub?.cancel();
      _likedCarIds.clear();
      if (user != null) _listenToLikedCars(user.uid);
      notifyListeners();
    });
  }

  List<Car> get cars => List.unmodifiable(_cars);
  bool get isLoading => _loading;

  List<Car> get carsWithVideo =>
      _cars.where((c) => c.videoPath != null && c.videoPath!.isNotEmpty).toList();

  List<Car> myCars(String uid) => _cars.where((c) => c.ownerId == uid).toList();

  /// Все лайкнутые мной авто — то, что раньше называлось "Избранное".
  List<Car> get likedCars =>
      _cars.where((c) => _likedCarIds.contains(c.id)).toList();

  bool isLikedByMe(String carId) => _likedCarIds.contains(carId);

  /// Находит авто по id среди уже загруженных карточек — используется,
  /// например, чтобы открыть CarDetailPage из уведомления (лайк/комментарий),
  /// зная только carId. Возвращает null, если такого авто нет в текущем
  /// списке (например, было удалено).
  Car? carById(String carId) {
    for (final c in _cars) {
      if (c.id == carId) return c;
    }
    return null;
  }

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

  /// Живой список ВСЕХ карточек-лайков этого пользователя сразу по всем
  /// авто — через collectionGroup по 'likedBy'. Требует поле 'uid' внутри
  /// каждого документа likedBy (пишем его в toggleLike ниже), т.к.
  /// collectionGroup не умеет фильтровать по id документа напрямую.
  void _listenToLikedCars(String uid) {
    _likedSub = _firestore
        .collectionGroup('likedBy')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      _likedCarIds
        ..clear()
        ..addAll(snapshot.docs.map((d) => d.reference.parent.parent!.id));
      notifyListeners();
    }, onError: (_) {
      // офлайн и т.п. — оставляем последнее известное состояние
    });
  }

  @override
  void dispose() {
    _carsSub?.cancel();
    _likedSub?.cancel();
    _authSub?.cancel();
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

  /// Больше не обязателен для отображения состояния лайка (это теперь
  /// делает глобальный listener выше), но оставлен как безобидный no-op
  /// wrapper, чтобы не ломать существующие вызовы loadLikeState(...) в
  /// video_page.dart / car_detail_page.dart.
  Future<void> loadLikeState(String carId) async {
    // no-op: состояние уже приходит через _listenToLikedCars
  }

  Future<void> toggleLike(String carId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final carRef = _firestore.collection('cars').doc(carId);
    final likeRef = carRef.collection('likedBy').doc(uid);
    final currentlyLiked = _likedCarIds.contains(carId);

    // Оптимистичное обновление — мгновенно во всех местах приложения.
    if (currentlyLiked) {
      _likedCarIds.remove(carId);
    } else {
      _likedCarIds.add(carId);
    }
    notifyListeners();

    try {
      if (currentlyLiked) {
        await likeRef.delete();
        await carRef.update({'likesCount': FieldValue.increment(-1)});
      } else {
        // 'uid' обязателен — по нему работает collectionGroup-запрос выше.
        await likeRef.set({
          'uid': uid,
          'likedAt': FieldValue.serverTimestamp(),
        });
        await carRef.update({'likesCount': FieldValue.increment(1)});

        // Уведомляем владельца объявления о новом лайке — ТОЛЬКО при
        // постановке лайка, не при снятии. NotificationSender сам
        // пропускает случай лайка своего же объявления.
        final car = carById(carId);
        NotificationSender.sendLike(
          toUid: car?.ownerId ?? '',
          carId: carId,
          carName: car?.name,
        );
      }
    } catch (_) {
      if (currentlyLiked) {
        _likedCarIds.add(carId);
      } else {
        _likedCarIds.remove(carId);
      }
      notifyListeners();
    }
  }

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