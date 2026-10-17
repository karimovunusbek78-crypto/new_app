// Unit tests for the Car model — the shape of the documents in the
// Firestore `cars` collection. They run without Firebase.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_app/src/pages/home/models/car.dart';

void main() {
  test('Car.fromFirestore fills defaults for missing fields', () {
    final car = Car.fromFirestore('abc', {'name': 'Chevrolet Cobalt'});

    expect(car.id, 'abc');
    expect(car.name, 'Chevrolet Cobalt');
    expect(car.price, '');
    expect(car.photoPaths, isEmpty);
    expect(car.videoPath, isNull);
    expect(car.likesCount, 0);
    expect(car.viewsCount, 0);
    expect(car.isAutosalonCar, isFalse);
    expect(car.createdAt, isNull);
  });

  test('Car.fromFirestore reads stats, media and autosalon fields', () {
    final created = DateTime(2026, 7, 1, 12);
    final car = Car.fromFirestore('xyz', {
      'name': 'Kia K5',
      'price': '25000',
      'ownerId': 'u1',
      'likesCount': 3,
      'viewsCount': 42,
      'photoPaths': ['https://example.com/1.jpg', 'https://example.com/2.jpg'],
      'videoPath': 'https://example.com/v.mp4',
      'autosalonId': 'u1',
      'autosalonName': 'Gravitas Auto',
      'isAutosalonCar': true,
      'createdAt': Timestamp.fromDate(created),
    });

    expect(car.ownerId, 'u1');
    expect(car.likesCount, 3);
    expect(car.viewsCount, 42);
    expect(car.photoPaths, hasLength(2));
    expect(car.videoPath, 'https://example.com/v.mp4');
    expect(car.isAutosalonCar, isTrue);
    expect(car.autosalonName, 'Gravitas Auto');
    expect(car.createdAt, created);
  });

  test('toFirestoreMap writes every field the app reads back', () {
    const car = Car(
      id: 'c1',
      name: 'BYD Song Plus',
      year: '2024',
      km: '1000',
      price: '30000',
      transmission: 'Автомат',
      fuelType: 'Электро',
      engineCapacity: '0',
      bodyType: 'Кроссовер',
      color: 'Белый',
      location: 'Ташкент',
      ownerId: 'u2',
      photoPaths: ['https://example.com/a.jpg'],
    );

    final map = car.toFirestoreMap();
    expect(map['ownerId'], 'u2');
    expect(map['photoPaths'], ['https://example.com/a.jpg']);
    expect(map['createdAt'], isA<FieldValue>());

    final back = Car.fromFirestore('c1', {...map, 'createdAt': null});
    expect(back.name, car.name);
    expect(back.price, car.price);
    expect(back.photoPaths, car.photoPaths);
  });

  test('copyWith changes only the given counters', () {
    const car = Car(
      id: 'c1', name: 'n', year: '', km: '', price: '', transmission: '',
      fuelType: '', engineCapacity: '', bodyType: '', color: '', location: '',
      likesCount: 1, viewsCount: 2,
    );
    final updated = car.copyWith(likesCount: 5);
    expect(updated.likesCount, 5);
    expect(updated.viewsCount, 2);
    expect(updated.name, 'n');
  });
}
