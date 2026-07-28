// lib/src/video/video_cache.dart
//
// КЕШ ВИДЕО: сетевые ролики скачиваются один раз и дальше играются
// с диска — лента открывается без «прогрузки». Локальные файлы
// (path не http) кеш не трогает.
//
// Требуется пакет в pubspec.yaml:
//   flutter_cache_manager: ^3.3.1

import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoCache {
  VideoCache._();

  static final CacheManager _manager = CacheManager(
    Config(
      'carVideoCache',
      stalePeriod: const Duration(days: 7), // храним неделю
      maxNrOfCacheObjects: 30, // не даём кешу разрастись
    ),
  );

  /// Мгновенная проверка: если ролик уже скачан — возвращаем файл,
  /// иначе null (БЕЗ скачивания, чтобы не блокировать плеер).
  static Future<File?> cachedFile(String url) async {
    try {
      final info = await _manager.getFileFromCache(url);
      final f = info?.file;
      if (f != null && await f.exists()) return f;
    } catch (_) {}
    return null;
  }

  /// Фоновая загрузка «на будущее» (fire-and-forget).
  /// Вызываем заранее — например, со страницы деталей или для
  /// следующих роликов в ленте — чтобы к моменту показа видео
  /// уже лежало на диске.
  static void prefetch(String? path) {
    if (path == null || !path.startsWith('http')) return;
    _manager.getSingleFile(path).catchError((_) => File(''));
  }
}