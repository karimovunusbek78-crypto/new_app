// lib/widgets/home_car_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_app/src/app/app_theme.dart';
import 'package:new_app/src/app/ui_kit.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:provider/provider.dart';

import 'package:new_app/src/pages/home/models/car.dart';

/// Карточка авто: фото-карусель сверху (с бейджами, ценой и сердечком
/// поверх), затем название, характеристики и нижняя строка с городом
/// и статистикой.
class HomeCarCard extends StatelessWidget {
  final Car car;
  final VoidCallback? onTap;

  /// Тап по иконке графика в углу фото — например, открыть аналитику
  /// по этому объявлению/видео. Необязательный.
  final VoidCallback? onStatsTap;

  const HomeCarCard({
    super.key,
    required this.car,
    this.onTap,
    this.onStatsTap,
  });

  @override
  Widget build(BuildContext context) {
    // Единый источник правды для лайков — CarsProvider, тот же, что и в
    // видео-ленте, на странице деталей и в «Избранном».
    final liked = context.select<CarsProvider, bool>(
      (p) => p.isLikedByMe(car.id),
    );
    final hasVideo = car.videoPath != null && car.videoPath!.isNotEmpty;

    final subtitle = [
      if (car.bodyType.trim().isNotEmpty) car.bodyType,
      if (car.driveType.trim().isNotEmpty) '${car.driveType} привод',
      if (car.condition.trim().isNotEmpty) car.condition,
    ].join(' · ');

    return Pressable(
      onTap: onTap,
      scale: 0.975,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: AppColors.softShadow(0.07),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Фото-карусель + оверлеи ──
            Stack(
              children: [
                CarPhotoCarousel(
                  photoPaths: car.photoPaths,
                  height: 26,
                  borderRadius: BorderRadius.zero,
                ),
                // Затемнение снизу — чтобы цена читалась на любом фото
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 90,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Row(
                    children: [
                      if (car.isAutosalonCar)
                        const _Badge(
                          icon: Icons.verified_rounded,
                          label: 'Автосалон',
                          color: AppColors.primary,
                        ),
                      if (car.isAutosalonCar && hasVideo)
                        const SizedBox(width: 6),
                      if (hasVideo)
                        const _Badge(
                          icon: Icons.play_arrow_rounded,
                          label: 'Видео',
                          color: AppColors.ink,
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      LikeButton(
                        liked: liked,
                        onTap: () =>
                            context.read<CarsProvider>().toggleLike(car.id),
                      ),
                      if (onStatsTap != null) ...[
                        const SizedBox(height: 8),
                        _CircleButton(
                          icon: Icons.bar_chart_rounded,
                          onTap: onStatsTap!,
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 22,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatPrice(car.price),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          shadows: [
                            Shadow(color: Colors.black38, blurRadius: 12),
                          ],
                        ),
                      ),
                      if (car.priceNegotiable) ...[
                        const SizedBox(width: 8),
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'торг',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // ── Контент ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          car.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      if (car.year.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            car.year,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _SpecsStrip(car: car),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 17,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          car.isAutosalonCar &&
                                  (car.autosalonName ?? '').isNotEmpty
                              ? '${car.autosalonName} · ${car.location}'
                              : car.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Stat(
                        icon: Icons.remove_red_eye_outlined,
                        value: car.viewsCount,
                      ),
                      const SizedBox(width: 10),
                      _Stat(
                        icon: Icons.favorite_border_rounded,
                        value: car.likesCount,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Полоса из 4 ключевых характеристик с разделителями.
class _SpecsStrip extends StatelessWidget {
  final Car car;
  const _SpecsStrip({required this.car});

  @override
  Widget build(BuildContext context) {
    final specs = <(IconData, String)>[
      if (car.km.trim().isNotEmpty) (Icons.speed_rounded, _km(car.km)),
      if (car.fuelType.trim().isNotEmpty)
        (Icons.local_gas_station_rounded, car.fuelType),
      if (car.transmission.trim().isNotEmpty)
        (Icons.settings_rounded, car.transmission),
      if (car.engineCapacity.trim().isNotEmpty)
        (Icons.bolt_rounded, _engine(car.engineCapacity)),
    ];
    if (specs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (int i = 0; i < specs.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 26, color: AppColors.hairline),
            Expanded(
              child: Column(
                children: [
                  Icon(specs[i].$1, size: 17, color: AppColors.inkSoft),
                  const SizedBox(height: 4),
                  Text(
                    specs[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _km(String raw) {
    final v = parseAmount(raw);
    if (v == null) return raw;
    return '${formatThousands(v)} км';
  }

  static String _engine(String raw) {
    final t = raw.trim();
    return RegExp(r'^\d+([.,]\d+)?$').hasMatch(t) ? '$t л' : t;
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final int value;
  const _Stat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: 3),
        Text(
          compactNumber(value),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.85,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          boxShadow: AppColors.softShadow(0.15),
        ),
        child: Icon(icon, color: AppColors.ink, size: 20),
      ),
    );
  }
}

/// Сердечко с "пружинным" увеличением при лайке.
class LikeButton extends StatefulWidget {
  final bool liked;
  final VoidCallback onTap;
  final double size;

  const LikeButton({
    super.key,
    required this.liked,
    required this.onTap,
    this.size = 40,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.35), weight: 35),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.35,
        end: 1,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_c);

  @override
  void didUpdateWidget(covariant LikeButton old) {
    super.didUpdateWidget(old);
    if (!old.liked && widget.liked) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          boxShadow: AppColors.softShadow(0.15),
        ),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(
              widget.liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              key: ValueKey(widget.liked),
              color: widget.liked ? AppColors.like : AppColors.ink,
              size: widget.size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
