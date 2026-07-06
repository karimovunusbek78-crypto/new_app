import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/pages/home/widgets/car_photo_caursel.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:new_app/src/video/video%20page/comments/comments_sheet.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:video_player/video_player.dart';

class CarDetailPage extends StatefulWidget {
  final Car car;
  const CarDetailPage({super.key, required this.car});

  @override
  State<CarDetailPage> createState() => _CarDetailPageState();
}

class _CarDetailPageState extends State<CarDetailPage> {
  static const _accent = Color(0xFF3A6FF8);
  static const _bg = Color(0xFFF6F6F8);
  static const _grey = Color(0xFF8A8A8E);

  // ----- Видео (ленивая инициализация — грузим только когда пользователь
  // нажал "Смотреть видео", чтобы не тратить трафик зря) -----
  VideoPlayerController? _video;
  bool _videoOpen = false;
  bool _videoReady = false;
  bool _videoError = false;
  bool _videoMuted = false;
  late final bool _hasVideo;

  // ----- Счётчик комментариев: та же логика, что и на видеостранице
  // (верхний уровень стримом + count() по replies каждого комментария) -----
  int _commentsTotal = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _commentsSub;
  int _recountGeneration = 0;

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      FirebaseFirestore.instance
          .collection('cars')
          .doc(widget.car.id)
          .collection('comments');

  @override
  void initState() {
    super.initState();

    final path = widget.car.videoPath;
    final isNetwork = path != null && path.startsWith('http');
    _hasVideo = path != null &&
        path.isNotEmpty &&
        (isNetwork || File(path).existsSync());

    context.read<CarsProvider>().loadLikeState(widget.car.id);

    _commentsSub = _commentsRef.snapshots().listen(
      _recountFromSnapshot,
      onError: (_) {/* offline — оставляем последнее значение */},
    );

    // КЛАВИАТУРА: на этой странице нет полей ввода, поэтому при открытии
    // принудительно снимаем фокус. Это лечит баг, когда фокус "переживал"
    // навигацию и клавиатура всплывала сама после возврата.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  Future<void> _recountFromSnapshot(
      QuerySnapshot<Map<String, dynamic>> snap) async {
    final generation = ++_recountGeneration;
    int total = snap.docs.length;
    await Future.wait(snap.docs.map((d) async {
      try {
        final agg = await d.reference.collection('replies').count().get();
        total += agg.count ?? 0;
      } catch (_) {}
    }));
    if (mounted && generation == _recountGeneration) {
      setState(() => _commentsTotal = total);
    }
  }

  Future<void> _refreshCommentsCount() async {
    try {
      final snap = await _commentsRef.get();
      await _recountFromSnapshot(snap);
    } catch (_) {}
  }

  @override
  void deactivate() {
    _video?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _commentsSub?.cancel();
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- actions

  /// Лайк синхронизирован с избранным: лайкнул — авто появляется на
  /// странице «Избранное», снял лайк — уходит оттуда.
  void _toggleLike() {
    final cars = context.read<CarsProvider>();
    final favs = context.read<FavoritesProvider>();
    final willLike = !cars.isLikedByMe(widget.car.id);
    cars.toggleLike(widget.car.id);
    if (favs.isFavorite(widget.car) != willLike) {
      favs.toggleFavorite(widget.car);
    }
  }

  Future<void> _openComments() async {
    _video?.pause();
    await CommentsSheet.show(context, widget.car.id);
    if (!mounted) return;
    // КЛАВИАТУРА: поле ввода живёт только в шторке комментариев.
    // После её закрытия жёстко снимаем фокус, чтобы клавиатура
    // не «вернулась» на страницу.
    FocusManager.instance.primaryFocus?.unfocus();
    _refreshCommentsCount();
  }

  void _pop() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(context);
  }

  void _soon(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  // ------------------------------------------------------------------ video

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  Future<void> _startVideo() async {
    if (_video != null) {
      setState(() => _videoOpen = true);
      _video!.play();
      return;
    }
    setState(() {
      _videoOpen = true;
      _videoError = false;
    });
    final path = widget.car.videoPath!;
    final c = path.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(path))
        : VideoPlayerController.file(File(path));
    _video = c;
    try {
      await c.initialize();
      if (!mounted) return;
      c.setLooping(true);
      c.setVolume(_videoMuted ? 0.0 : 1.0);
      c.addListener(_onVideoTick);
      setState(() => _videoReady = true);
      c.play();
    } catch (_) {
      if (mounted) setState(() => _videoError = true);
    }
  }

  void _collapseVideo() {
    _video?.pause();
    setState(() => _videoOpen = false);
  }

  void _toggleVideoPlay() {
    final c = _video;
    if (c == null || !_videoReady) return;
    c.value.isPlaying ? c.pause() : c.play();
    setState(() {});
  }

  void _toggleVideoMute() {
    _videoMuted = !_videoMuted;
    _video?.setVolume(_videoMuted ? 0.0 : 1.0);
    setState(() {});
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    final liked = context.watch<CarsProvider>().isLikedByMe(car.id);

    return Scaffold(
      backgroundColor: _bg,
      // На странице нет полей ввода — не даём клавиатуре двигать layout.
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(child: _header(car)),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 2.h),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _titleCard(car),
                      if (_hasVideo) ...[
                        SizedBox(height: 1.5.h),
                        _videoCard(car),
                      ],
                      SizedBox(height: 1.5.h),
                      _specsCard(car),
                      if (car.description.trim().isNotEmpty) ...[
                        SizedBox(height: 1.5.h),
                        _textCard('Описание', car.description),
                      ],
                      if (car.changesDescription.trim().isNotEmpty) ...[
                        SizedBox(height: 1.5.h),
                        _textCard('Что было изменено', car.changesDescription),
                      ],
                      SizedBox(height: 1.5.h),
                      _contactsCard(car),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          _bottomBar(car, liked),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- header

  Widget _header(Car car) {
    return Stack(
      children: [
        CarPhotoCarousel(photoPaths: car.photoPaths, height: 34),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
              child: Row(
                children: [
                  _circleButton(Icons.arrow_back_rounded, _pop),
                  const Spacer(),
                  _circleButton(Icons.share_outlined,
                      () => _soon('Скоро можно будет делиться объявлением')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 5.2.h,
        height: 5.2.h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: 2.6.h),
      ),
    );
  }

  // ------------------------------------------------------------------ cards

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      );

  Widget _titleCard(Car car) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            car.name,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              height: 1.15,
            ),
          ),
          SizedBox(height: 0.6.h),
          Text(
            '${car.year} год · ${car.km} км',
            style: TextStyle(fontSize: 12.5.sp, color: _grey),
          ),
          SizedBox(height: 1.4.h),
          Row(
            children: [
              Text(
                _priceText(car),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                ),
              ),
              if (car.priceNegotiable) ...[
                SizedBox(width: 2.5.w),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.4.h),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2.h),
                  ),
                  child: Text(
                    'Торг',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: _accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _priceText(Car car) {
    final p = car.price.trim();
    if (p.isEmpty) return 'Цена не указана';
    return p.contains('\$') ? p : '\$$p';
  }

  // ------------------------------------------------------------- video card

  Widget _videoCard(Car car) {
    return _card(
      padding: EdgeInsets.all(2.5.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3.5.w),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _videoOpen ? _videoPlayer() : _videoPoster(car),
        ),
      ),
    );
  }

  Widget _videoPoster(Car car) {
    return GestureDetector(
      onTap: _startVideo,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            car.photoPaths.isNotEmpty
                ? _image(car.photoPaths.first)
                : Container(color: const Color(0xFF111111)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                width: 8.h,
                height: 8.h,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Icon(Icons.play_arrow_rounded,
                    color: _accent, size: 4.5.h),
              ),
            ),
            Positioned(
              left: 3.5.w,
              bottom: 1.4.h,
              right: 3.5.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Смотреть видеообзор',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8)
                      ],
                    ),
                  ),
                  SizedBox(height: 0.3.h),
                  Text(
                    'Видео от продавца этого авто',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11.5.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoPlayer() {
    if (_videoError) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: const Color(0xFF111111),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded,
                    color: Colors.white54, size: 4.h),
                SizedBox(height: 1.h),
                Text(
                  'Не удалось загрузить видео',
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                ),
                SizedBox(height: 1.h),
                TextButton(
                  onPressed: _collapseVideo,
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final c = _video;
    if (c == null || !_videoReady) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Color(0xFF111111),
          child: Center(
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          ),
        ),
      );
    }

    final playing = c.value.isPlaying;
    return AspectRatio(
      aspectRatio: c.value.aspectRatio,
      child: GestureDetector(
        onTap: _toggleVideoPlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(c),
            AnimatedOpacity(
              opacity: playing ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: Container(
                color: Colors.black26,
                child: Center(
                  child: Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 7.h),
                ),
              ),
            ),
            Positioned(
              top: 1.h,
              right: 2.5.w,
              child: Row(
                children: [
                  _videoOverlayButton(
                    _videoMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    _toggleVideoMute,
                  ),
                  SizedBox(width: 2.w),
                  _videoOverlayButton(Icons.close_rounded, _collapseVideo),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                  playedColor: _accent,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoOverlayButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 4.4.h,
        height: 4.4.h,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 2.4.h),
      ),
    );
  }

  Widget _image(String path, {BoxFit fit = BoxFit.cover}) {
    Widget fallback() => Container(color: const Color(0xFF111111));
    if (path.startsWith('http')) {
      return Image.network(path,
          fit: fit, errorBuilder: (_, __, ___) => fallback());
    }
    final isFile = path.startsWith('/') || File(path).existsSync();
    if (isFile) {
      return Image.file(File(path),
          fit: fit, errorBuilder: (_, __, ___) => fallback());
    }
    return Image.asset(path,
        fit: fit, errorBuilder: (_, __, ___) => fallback());
  }

  // ------------------------------------------------------------- specs card

  Widget _specsCard(Car car) {
    final items = <MapEntry<String, String>>[
      MapEntry('Коробка', car.transmission),
      MapEntry('Топливо', car.fuelType),
      MapEntry('Объём', car.engineCapacity),
      MapEntry('Кузов', car.bodyType),
      MapEntry('Привод', car.driveType),
      MapEntry('Цвет', car.color),
      MapEntry('Состояние', car.condition),
      MapEntry('Владельцев', car.ownersCount),
      MapEntry('Город', car.location),
    ].where((e) => e.value.trim().isNotEmpty).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Характеристики'),
          SizedBox(height: 1.5.h),
          ...List.generate(items.length, (i) {
            final e = items[i];
            return Column(
              children: [
                if (i > 0)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 1.h),
                    child: Container(
                        height: 1, color: const Color(0xFFF0F0F3)),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style:
                            TextStyle(fontSize: 12.5.sp, color: _grey),
                      ),
                    ),
                    Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _textCard(String title, String text) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          SizedBox(height: 1.h),
          Text(
            text,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.black87,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactsCard(Car car) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Контакты'),
          SizedBox(height: 1.2.h),
          if (car.phone.trim().isNotEmpty)
            Row(
              children: [
                Container(
                  width: 4.8.h,
                  height: 4.8.h,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.phone_outlined, color: _accent, size: 2.3.h),
                ),
                SizedBox(width: 3.w),
                Text(
                  car.phone,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            )
          else
            Text('Телефон не указан',
                style: TextStyle(fontSize: 12.5.sp, color: _grey)),
          if (car.contactWhatsapp || car.contactTelegram) ...[
            SizedBox(height: 1.4.h),
            Row(
              children: [
                if (car.contactWhatsapp)
                  _contactBadge('WhatsApp', Icons.chat_outlined),
                if (car.contactWhatsapp && car.contactTelegram)
                  SizedBox(width: 2.w),
                if (car.contactTelegram)
                  _contactBadge('Telegram', Icons.send_outlined),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _contactBadge(String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(2.h),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 1.8.h, color: Colors.black),
          SizedBox(width: 1.5.w),
          Text(label,
              style:
                  TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- bottom bar

  Widget _bottomBar(Car car, bool liked) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEFEFEF))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
          child: Row(
            children: [
              _barButton(
                icon: liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                iconColor: liked ? Colors.red : Colors.black,
                label: 'Нравится',
                onTap: _toggleLike,
              ),
              SizedBox(width: 5.w),
              _barButton(
                icon: Icons.mode_comment_outlined,
                iconColor: Colors.black,
                label: _commentsTotal > 0
                    ? 'Комментарии · $_commentsTotal'
                    : 'Комментарии',
                onTap: _openComments,
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _soon('Скоро можно будет делиться объявлением'),
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.share_outlined,
                    color: Colors.black, size: 2.6.h),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 2.6.h),
          SizedBox(width: 1.5.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}