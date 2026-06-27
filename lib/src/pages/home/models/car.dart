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

  // ── New fields ────────────────────────────────────────────────
  // All have safe defaults so existing `const Car(...)` entries (e.g. in
  // cars_data.dart) keep compiling without changes.
  final String ownersCount; // Количество владельцев
  final String description; // Описание
  final String driveType; // Привод: Передний / Задний / Полный
  final String condition; // Состояние: Новый / Б.у. / После аварии / Требует ремонта
  final List<String> photoPaths; // Локальные пути к фото (макс. 4)
  final String? videoPath; // Локальный путь к видео (опционально)

  // ── Negotiation / changes / contact fields ──────────────────────
  final bool priceNegotiable; // Цена обсуждается (торг)
  final String changesDescription; // Что изменено / отремонтировано
  final String phone; // Контактный номер телефона (обязателен)
  final bool contactWhatsapp; // Можно писать в WhatsApp
  final bool contactTelegram; // Можно писать в Telegram

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
    this.ownersCount = '',
    this.description = '',
    this.driveType = '',
    this.condition = '',
    this.photoPaths = const [],
    this.videoPath,
    this.priceNegotiable = false,
    this.changesDescription = '',
    this.phone = '',
    this.contactWhatsapp = false,
    this.contactTelegram = false,
  });
}