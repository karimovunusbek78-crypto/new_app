import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/models/car.dart';

class CarsProvider extends ChangeNotifier {
  final List<Car> _cars = [];

  List<Car> get cars => List.unmodifiable(_cars);

  // Cars that have a video attached — used by VideoPage.
  List<Car> get carsWithVideo =>
      _cars.where((c) => c.videoPath != null && c.videoPath!.isNotEmpty).toList();

  void addCar(Car car) {
    _cars.insert(0, car);
    notifyListeners();
  }
}