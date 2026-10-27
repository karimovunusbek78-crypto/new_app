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
}
