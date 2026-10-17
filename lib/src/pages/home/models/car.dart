import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String ownersCount;
  final String description;
  final String driveType;
  final String condition;
  final List<String> photoPaths;
  final String? videoPath;
  final bool priceNegotiable;
  final String changesDescription;
  final String phone;
  final bool contactWhatsapp;
  final bool contactTelegram;

  // ── Firestore / stats fields ────────────────────────────────────
  final String ownerId;       // uid владельца объявления
  final int likesCount;
  final int viewsCount;
  final DateTime? createdAt;  // null пока не пришло из Firestore

  // ── Автосалон ────────────────────────────────────────────────────
  // Заполняются только для авто, опубликованных через AutoslonPublishPage
  // (см. cars/{id}.autosalonId и т.д.). Для обычных объявлений частных
  // продавцов autosalonId == null и isAutosalonCar == false.
  final String? autosalonId;       // uid автосалона == id документа autosalons/{uid}
  final String? autosalonName;
  final String? autosalonLogoUrl;
  final bool isAutosalonCar;

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
    this.ownerId = '',
    this.likesCount = 0,
    this.viewsCount = 0,
    this.createdAt,
    this.autosalonId,
    this.autosalonName,
    this.autosalonLogoUrl,
    this.isAutosalonCar = false,
  });

  /// Только текст + статы — без photoPaths/videoPath (их пока не грузим).
  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': name,
      'year': year,
      'km': km,
      'price': price,
      'transmission': transmission,
      'fuelType': fuelType,
      'engineCapacity': engineCapacity,
      'bodyType': bodyType,
      'color': color,
      'location': location,
      'ownersCount': ownersCount,
      'description': description,
      'driveType': driveType,
      'condition': condition,
      'priceNegotiable': priceNegotiable,
      'changesDescription': changesDescription,
      'phone': phone,
      'contactWhatsapp': contactWhatsapp,
      'contactTelegram': contactTelegram,
      'ownerId': ownerId,
      'likesCount': likesCount,
      'viewsCount': viewsCount,
      'photoPaths': photoPaths,   // ← добавлено (уже будут Storage-URL, не локальные пути)
      'videoPath': videoPath,
      'autosalonId': autosalonId,
      'autosalonName': autosalonName,
      'autosalonLogoUrl': autosalonLogoUrl,
      'isAutosalonCar': isAutosalonCar,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Car.fromFirestore(String id, Map<String, dynamic> data) {
    return Car(
      id: id,
      name: data['name'] ?? '',
      year: data['year'] ?? '',
      km: data['km'] ?? '',
      price: data['price'] ?? '',
      transmission: data['transmission'] ?? '',
      fuelType: data['fuelType'] ?? '',
      engineCapacity: data['engineCapacity'] ?? '',
      bodyType: data['bodyType'] ?? '',
      color: data['color'] ?? '',
      location: data['location'] ?? '',
      ownersCount: data['ownersCount'] ?? '',
      description: data['description'] ?? '',
      driveType: data['driveType'] ?? '',
      condition: data['condition'] ?? '',
      priceNegotiable: data['priceNegotiable'] ?? false,
      changesDescription: data['changesDescription'] ?? '',
      phone: data['phone'] ?? '',
      contactWhatsapp: data['contactWhatsapp'] ?? false,
      contactTelegram: data['contactTelegram'] ?? false,
      ownerId: data['ownerId'] ?? '',
      likesCount: data['likesCount'] ?? 0,
      viewsCount: data['viewsCount'] ?? 0,
      photoPaths: List<String>.from(data['photoPaths'] ?? const []), // ← добавлено
      videoPath: data['videoPath'] as String?,
      autosalonId: data['autosalonId'] as String?,
      autosalonName: data['autosalonName'] as String?,
      autosalonLogoUrl: data['autosalonLogoUrl'] as String?,
      isAutosalonCar: data['isAutosalonCar'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Алиас для fromFirestore — используется там, где карточка авто
  /// строится из уже полученного QueryDocumentSnapshot.data() внутри
  /// StreamBuilder (например, AutosalonStatsPage._carGridTile), а не
  /// через сам провайдер.
  factory Car.fromMap(String id, Map<String, dynamic> data) =>
      Car.fromFirestore(id, data);

  Car copyWith({
    int? likesCount,
    int? viewsCount,
    List<String>? photoPaths,
    String? videoPath,
    String? autosalonId,
    String? autosalonName,
    String? autosalonLogoUrl,
    bool? isAutosalonCar,
  }) {
    return Car(
      id: id, name: name, year: year, km: km, price: price,
      transmission: transmission, fuelType: fuelType, engineCapacity: engineCapacity,
      bodyType: bodyType, color: color, location: location, ownersCount: ownersCount,
      description: description, driveType: driveType, condition: condition,
      photoPaths: photoPaths ?? this.photoPaths, videoPath: videoPath ?? this.videoPath,
      priceNegotiable: priceNegotiable, changesDescription: changesDescription, phone: phone,
      contactWhatsapp: contactWhatsapp, contactTelegram: contactTelegram, ownerId: ownerId,
      likesCount: likesCount ?? this.likesCount, viewsCount: viewsCount ?? this.viewsCount,
      createdAt: createdAt,
      autosalonId: autosalonId ?? this.autosalonId,
      autosalonName: autosalonName ?? this.autosalonName,
      autosalonLogoUrl: autosalonLogoUrl ?? this.autosalonLogoUrl,
      isAutosalonCar: isAutosalonCar ?? this.isAutosalonCar,
    );
  }
}