import 'package:new_app/src/pages/home/models/car.dart';

enum SortMode { newest, cheapest, priciest, popular, newestYear }

extension SortModeLabel on SortMode {
  String get label => switch (this) {
    SortMode.newest => 'Новые',
    SortMode.cheapest => 'Дешевле',
    SortMode.priciest => 'Дороже',
    SortMode.popular => 'Популярные',
    SortMode.newestYear => 'Год ↓',
  };
}

/// Значения совпадают с теми, что пишут формы публикации
/// (CarPublishPage / AutoslonPublishPage) — иначе фильтр ничего не найдёт.
class SearchOptions {
  static const transmissions = ['Механика', 'Автомат', 'Робот', 'Вариатор'];
  static const fuelTypes = ['Бензин', 'Дизель', 'Газ', 'Электро', 'Гибрид'];
  static const bodyTypes = [
    'Седан',
    'Хэтчбек',
    'Внедорожник',
    'Универсал',
    'Купе',
    'Минивэн',
  ];
  static const driveTypes = ['Передний', 'Задний', 'Полный'];
}

class SearchFilters {
  final int? minPrice;
  final int? maxPrice;
  final int? yearFrom;
  final int? yearTo;
  final Set<String> fuelTypes;
  final Set<String> transmissions;
  final Set<String> bodyTypes;
  final Set<String> driveTypes;
  final bool onlyVideo;
  final bool onlyAutosalon;

  const SearchFilters({
    this.minPrice,
    this.maxPrice,
    this.yearFrom,
    this.yearTo,
    this.fuelTypes = const {},
    this.transmissions = const {},
    this.bodyTypes = const {},
    this.driveTypes = const {},
    this.onlyVideo = false,
    this.onlyAutosalon = false,
  });

  /// Сколько фильтров включено — для бейджа на кнопке фильтров.
  /// "Только видео" не считаем: у него свой чип на экране.
  int get activeCount =>
      (minPrice != null || maxPrice != null ? 1 : 0) +
      (yearFrom != null || yearTo != null ? 1 : 0) +
      (fuelTypes.isNotEmpty ? 1 : 0) +
      (transmissions.isNotEmpty ? 1 : 0) +
      (bodyTypes.isNotEmpty ? 1 : 0) +
      (driveTypes.isNotEmpty ? 1 : 0) +
      (onlyAutosalon ? 1 : 0);

  bool get isEmpty => activeCount == 0 && !onlyVideo;

  SearchFilters copyWith({
    int? Function()? minPrice,
    int? Function()? maxPrice,
    int? Function()? yearFrom,
    int? Function()? yearTo,
    Set<String>? fuelTypes,
    Set<String>? transmissions,
    Set<String>? bodyTypes,
    Set<String>? driveTypes,
    bool? onlyVideo,
    bool? onlyAutosalon,
  }) {
    return SearchFilters(
      minPrice: minPrice != null ? minPrice() : this.minPrice,
      maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
      yearFrom: yearFrom != null ? yearFrom() : this.yearFrom,
      yearTo: yearTo != null ? yearTo() : this.yearTo,
      fuelTypes: fuelTypes ?? this.fuelTypes,
      transmissions: transmissions ?? this.transmissions,
      bodyTypes: bodyTypes ?? this.bodyTypes,
      driveTypes: driveTypes ?? this.driveTypes,
      onlyVideo: onlyVideo ?? this.onlyVideo,
      onlyAutosalon: onlyAutosalon ?? this.onlyAutosalon,
    );
  }

  /// Сбрасывает всё, кроме чипа "Только видео".
  SearchFilters cleared() => SearchFilters(onlyVideo: onlyVideo);
}

/// Достаёт целое число из пользовательского текста цены/года:
/// "15 000", "15,000 $", "15000.00" → 15000. Раньше использовался
/// double.tryParse, который на "100 000" возвращал null — и фильтр
/// по цене молча не работал.
int? parseAmount(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  // Отбрасываем копейки/центы: "15000.50" / "15000,5"
  s = s.replaceFirst(RegExp(r'[.,]\d{1,2}\s*\D*$'), '');
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

/// "15000" → "$15 000". Если в тексте нет цифр — возвращаем как есть.
String formatPrice(String raw) {
  final value = parseAmount(raw);
  if (value == null) return raw.trim().isEmpty ? 'Цена не указана' : raw;
  return '\$${formatThousands(value)}';
}

String formatThousands(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Нормализация для поиска: регистр, ё→е, э→е (чтобы "Хэтчбэк" находил
/// "Хэтчбек"), дефисы как пробелы.
String _norm(String s) => s
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll('э', 'е')
    .replaceAll(RegExp(r'[-_/]'), ' ');

/// Русские написания популярных марок → как их обычно пишут в названии.
const _brandSynonyms = {
  'мерседес': 'mercedes',
  'мерс': 'mercedes',
  'бмв': 'bmw',
  'ауди': 'audi',
  'тойота': 'toyota',
  'лексус': 'lexus',
  'киа': 'kia',
  'хендай': 'hyundai',
  'хундай': 'hyundai',
  'хюндай': 'hyundai',
  'тесла': 'tesla',
  'шевроле': 'chevrolet',
  'хонда': 'honda',
  'ниссан': 'nissan',
  'мазда': 'mazda',
  'фольксваген': 'volkswagen',
  'порше': 'porsche',
  'лада': 'lada',
  'рендж': 'range',
  'ленд': 'land',
};

String _haystack(Car c) => _norm(
  [
    c.name,
    c.year,
    c.bodyType,
    c.color,
    c.location,
    c.fuelType,
    c.engineCapacity,
    c.transmission,
    c.driveType,
    c.condition,
    c.autosalonName ?? '',
  ].join(' '),
);

bool _matchesQuery(Car car, String query) {
  final tokens = _norm(query).split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  if (tokens.isEmpty) return true;
  final hay = _haystack(car);
  // Каждое слово запроса должно найтись хоть где-то в карточке —
  // так "bmw 2020 автомат" находит BMW 2020 года на автомате.
  for (final t in tokens) {
    final syn = _brandSynonyms[_norm(t)];
    if (!hay.contains(t) && (syn == null || !hay.contains(syn))) return false;
  }
  return true;
}

bool _hasVideo(Car c) => c.videoPath != null && c.videoPath!.isNotEmpty;

List<Car> applySearch(
  List<Car> source, {
  required String query,
  required SearchFilters filters,
  required SortMode sort,
}) {
  final f = filters;
  final result = source.where((car) {
    if (f.onlyVideo && !_hasVideo(car)) return false;
    if (f.onlyAutosalon && !car.isAutosalonCar) return false;
    if (f.fuelTypes.isNotEmpty && !f.fuelTypes.contains(car.fuelType)) {
      return false;
    }
    if (f.transmissions.isNotEmpty &&
        !f.transmissions.contains(car.transmission)) {
      return false;
    }
    if (f.bodyTypes.isNotEmpty &&
        !f.bodyTypes.any((b) => _norm(b) == _norm(car.bodyType))) {
      return false;
    }
    if (f.driveTypes.isNotEmpty && !f.driveTypes.contains(car.driveType)) {
      return false;
    }
    if (f.minPrice != null || f.maxPrice != null) {
      final price = parseAmount(car.price);
      if (price == null) return false;
      if (f.minPrice != null && price < f.minPrice!) return false;
      if (f.maxPrice != null && price > f.maxPrice!) return false;
    }
    if (f.yearFrom != null || f.yearTo != null) {
      final year = parseAmount(car.year);
      if (year == null) return false;
      if (f.yearFrom != null && year < f.yearFrom!) return false;
      if (f.yearTo != null && year > f.yearTo!) return false;
    }
    return _matchesQuery(car, query);
  }).toList();

  int priceOf(Car c) => parseAmount(c.price) ?? 0;
  switch (sort) {
    case SortMode.newest:
      break; // CarsProvider уже отдаёт по createdAt desc
    case SortMode.cheapest:
      result.sort((a, b) => priceOf(a).compareTo(priceOf(b)));
    case SortMode.priciest:
      result.sort((a, b) => priceOf(b).compareTo(priceOf(a)));
    case SortMode.popular:
      result.sort(
        (a, b) => (b.viewsCount + b.likesCount * 3).compareTo(
          a.viewsCount + a.likesCount * 3,
        ),
      );
    case SortMode.newestYear:
      result.sort(
        (a, b) =>
            (parseAmount(b.year) ?? 0).compareTo(parseAmount(a.year) ?? 0),
      );
  }
  return result;
}
