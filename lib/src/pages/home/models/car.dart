// lib/models/car.dart

class Car {
  final String id;
  final String name;
  final String year;
  final String km;
  final String price;
  final String transmission;
  final String fuelType;
  final String engineCapacity;
  final String bodyType;
  final String color;
  final String location;

  const Car({
    required this.id,
    required this.name,
    required this.year,
    required this.km,
    required this.price,
    required this.transmission,
    required this.fuelType,
    required this.engineCapacity,
    required this.bodyType,
    required this.color,
    required this.location,
  });
}