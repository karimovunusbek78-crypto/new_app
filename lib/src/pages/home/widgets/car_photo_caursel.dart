import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class CarPhotoCarousel extends StatefulWidget {
  final List<String> photoPaths;
  final double height; // in .h units
  final BorderRadius borderRadius;

  const CarPhotoCarousel({
    super.key,
    required this.photoPaths,
    this.height = 15,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<CarPhotoCarousel> createState() => _CarPhotoCarouselState();
}

class _CarPhotoCarouselState extends State<CarPhotoCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photoPaths;

    if (photos.isEmpty) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: Container(
          width: double.infinity,
          height: widget.height.h,
          color: const Color(0xFFE5E5EA),
          child: Center(
            child: Icon(
              Icons.directions_car_rounded,
              size: 7.h,
              color: const Color(0xFFC7C7CC),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height.h,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // ФИКС: реальные пиксели экрана под размер карточки —
                // декодируем/кешируем фото ИМЕННО под этот размер, а не
                // в полном разрешении камеры (4000x3000 и т.п.). Раньше
                // каждая фотка декодировалась в оригинальном размере
                // при каждой перестройке виджета — это и было причиной
                // "грузит долго / не плавно" при скролле списков.
                final dpr = MediaQuery.of(context).devicePixelRatio;
                final cacheW = (constraints.maxWidth * dpr).round();
                final cacheH = (widget.height.h * dpr).round();

                return PageView.builder(
                  controller: _controller,
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) {
                    final path = photos[i];
                    return _CarouselImage(
                      path: path,
                      cacheWidth: cacheW,
                      cacheHeight: cacheH,
                    );
                  },
                );
              },
            ),
            if (photos.length > 1)
              Padding(
                padding: EdgeInsets.only(bottom: 1.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(photos.length, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.symmetric(horizontal: 0.5.w),
                      width: active ? 2.2.w : 1.6.w,
                      height: 1.6.w,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(1.h),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Отдельный виджет для одного фото — с ключом по [path], чтобы Flutter
/// переиспользовал уже созданный элемент (и его декодированное изображение
/// в памяти) вместо пересоздания с нуля при каждой перестройке PageView.
class _CarouselImage extends StatelessWidget {
  final String path;
  final int cacheWidth;
  final int cacheHeight;

  const _CarouselImage({
    required this.path,
    required this.cacheWidth,
    required this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isNetwork = path.startsWith('http');

    if (isNetwork) {
      // CachedNetworkImage: качает файл ОДИН раз и кладёт на диск —
      // при следующем показе (даже после перезапуска приложения) грузится
      // мгновенно из локального кеша, без повторного запроса в сеть.
      // memCacheWidth/Height — ещё и держит в памяти уже уменьшенную
      // версию, а не оригинал в полный размер.
      return CachedNetworkImage(
        key: ValueKey(path),
        imageUrl: path,
        fit: BoxFit.cover,
        width: double.infinity,
        memCacheWidth: cacheWidth > 0 ? cacheWidth : null,
        memCacheHeight: cacheHeight > 0 ? cacheHeight : null,
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (_, __) => Container(color: const Color(0xFFE5E5EA)),
        errorWidget: (_, __, ___) => Container(
          color: const Color(0xFFE5E5EA),
          child: const Icon(Icons.directions_car_rounded,
              color: Color(0xFFC7C7CC)),
        ),
      );
    }

    // Локальный файл: cacheWidth/cacheHeight заставляют Flutter декодировать
    // сразу в уменьшенном размере (а не в оригинальном разрешении камеры),
    // gaplessPlayback убирает "мигание" пустым местом при смене кадра.
    return Image.file(
      File(path),
      key: ValueKey(path),
      fit: BoxFit.cover,
      width: double.infinity,
      gaplessPlayback: true,
      cacheWidth: cacheWidth > 0 ? cacheWidth : null,
      cacheHeight: cacheHeight > 0 ? cacheHeight : null,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFE5E5EA),
        child: const Icon(Icons.directions_car_rounded,
            color: Color(0xFFC7C7CC)),
      ),
    );
  }
}