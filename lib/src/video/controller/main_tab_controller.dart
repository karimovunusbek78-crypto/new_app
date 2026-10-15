import 'package:flutter/foundation.dart';
import 'package:new_app/src/pages/home/models/car.dart';

/// Единая точка управления нижней навигацией `MainNavBar`.
///
/// Зачем это нужно: раньше "Смотреть в ленте" на странице деталей делал
/// Navigator.push(VideoPage(...)) — это открывало ленту отдельным
/// full-screen роутом БЕЗ нижнего navbar (у него просто нет своего
/// bottomNavigationBar). Теперь вместо push мы возвращаемся к MainNavBar
/// и программно переключаем таб на "Видео" — navbar остаётся на экране.
class NavTabController extends ChangeNotifier {
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  /// Одноразовый запрос: id авто, на видео которого нужно перейти в ленте.
  /// VideoPage сама считывает это значение и сбрасывает его после перехода
  /// (см. clearPendingVideoCarId), чтобы повторный build не прыгал снова.
  String? pendingVideoCarId;

  /// Если лента была открыта кнопкой «Смотреть в ленте» со страницы
  /// деталей — здесь лежит это авто. VideoPage показывает стрелку «назад»,
  /// пока это значение не null, и тапом по ней возвращает пользователя
  /// на CarDetailPage этого авто.
  Car? _cameFromDetailCar;
  Car? get cameFromDetailCar => _cameFromDetailCar;

  /// Обычное переключение таба (тап по нижнему бару). Сбрасывает контекст
  /// «пришли со страницы деталей» — стрелка назад больше не нужна, это
  /// уже осознанный переход пользователя в другой таб.
  void setIndex(int index) {
    _cameFromDetailCar = null;
    if (_currentIndex == index) {
      notifyListeners();
      return;
    }
    _currentIndex = index;
    notifyListeners();
  }

  /// Переключает на таб "Видео" и просит ленту сразу перейти
  /// на видео конкретного авто. Без стрелки назад — обычный переход.
  void openVideoFeed({String? carId}) {
    _cameFromDetailCar = null;
    pendingVideoCarId = carId;
    _currentIndex = 2;
    notifyListeners();
  }

  /// То же самое, но со страницы деталей — включает стрелку «назад»
  /// в ленте, которая вернёт пользователя обратно на CarDetailPage.
  void openVideoFeedFromDetail(Car car) {
    _cameFromDetailCar = car;
    pendingVideoCarId = car.id;
    _currentIndex = 2;
    notifyListeners();
  }

  /// Вызывается из VideoPage после того, как переход выполнен.
  void clearPendingVideoCarId() {
    pendingVideoCarId = null;
  }

  /// Вызывается из VideoPage, когда пользователь тапнул на стрелку
  /// «назад» и она уже обработана (открыт CarDetailPage).
  void clearCameFromDetail() {
    _cameFromDetailCar = null;
    notifyListeners();
  }
}