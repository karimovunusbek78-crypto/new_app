// Unit tests for the Car model — the shape of the documents in the
// Firestore `cars` collection. They run without Firebase.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/search/search_filters.dart';

Car _car({
  String id = '1',
  String name = 'BMW X5',
  String year = '2020',
  String price = '45 000',
  String bodyType = 'Внедорожник',
  String fuelType = 'Бензин',
  String transmission = 'Автомат',
  String location = 'Алматы',
  String? videoPath,
  int views = 0,
}) =>
    Car(
      id: id,
      name: name,
      year: year,
      km: '50000',
      price: price,
      transmission: transmission,
      fuelType: fuelType,
      engineCapacity: '3.0',
      bodyType: bodyType,
      color: 'Чёрный',
      location: location,
      videoPath: videoPath,
      viewsCount: views,
    );

void main() {
  group('parseAmount', () {
    test('handles spaces, currency and cents', () {
      expect(parseAmount('100 000'), 100000);
      expect(parseAmount('15,000 \$'), 15000);
      expect(parseAmount('15000.50'), 15000);
      expect(parseAmount(''), isNull);
      expect(parseAmount('договорная'), isNull);
    });
  });

  group('applySearch', () {
    final cars = [
      _car(id: 'a', name: 'BMW X5', price: '45 000', year: '2020'),
      _car(
          id: 'b',
          name: 'Toyota Camry',
          price: '25 000',
          year: '2018',
          bodyType: 'Седан',
          videoPath: 'https://v'),
      _car(
          id: 'c',
          name: 'Hyundai i30',
          price: '12 000',
          year: '2015',
          bodyType: 'Хэтчбек',
          transmission: 'Механика'),
    ];

    List<String> ids(List<Car> r) => r.map((c) => c.id).toList();

    test('multi-word query matches across fields', () {
      final r = applySearch(cars,
          query: 'bmw 2020 автомат',
          filters: const SearchFilters(),
          sort: SortMode.newest);
      expect(ids(r), ['a']);
    });

    test('russian brand synonyms and э/е normalisation', () {
      expect(
          ids(applySearch(cars,
              query: 'тойота',
              filters: const SearchFilters(),
              sort: SortMode.newest)),
          ['b']);
      expect(
          ids(applySearch(cars,
              query: 'хэтчбэк',
              filters: const SearchFilters(),
              sort: SortMode.newest)),
          ['c']);
    });

    test('price range and sort', () {
      final r = applySearch(cars,
          query: '',
          filters: const SearchFilters(minPrice: 20000),
          sort: SortMode.cheapest);
      expect(ids(r), ['b', 'a']);
    });

    test('only video and body type filters', () {
      expect(
          ids(applySearch(cars,
              query: '',
              filters: const SearchFilters(onlyVideo: true),
              sort: SortMode.newest)),
          ['b']);
      expect(
          ids(applySearch(cars,
              query: '',
              filters: const SearchFilters(bodyTypes: {'Хэтчбек'}),
              sort: SortMode.newest)),
          ['c']);
    });
  });

  test('formatPrice', () {
    expect(formatPrice('15000'), '\$15 000');
    expect(formatPrice(''), 'Цена не указана');
  });


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
