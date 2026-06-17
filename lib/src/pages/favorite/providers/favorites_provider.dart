// lib/providers/favorites_provider.dart
import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/pages.dart';

class FavoritesProvider extends ChangeNotifier {
  final List<Car> _favorites = [];

  List<Car> get favorites => List.unmodifiable(_favorites);

  bool isFavorite(Car car) => _favorites.any((c) => c.id == car.id);

  void toggleFavorite(Car car) {
    if (isFavorite(car)) {
      _favorites.removeWhere((c) => c.id == car.id);
    } else {
      _favorites.add(car);
    }
    notifyListeners();
  }
}