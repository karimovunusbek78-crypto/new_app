import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:video_player/video_player.dart';

import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/pages/car_detail_page.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/pages/pages.dart'; // FavoritesProvider

class VideoPage extends StatefulWidget {
  const VideoPage({Key? key}) : super(key: key);

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Global sound toggle — stays consistent as you swipe between reels.
  bool _muted = false;

  // Author (publisher) info pulled straight from the profile — shown as the
  // "@creator" block on every reel, like @AutoDrive in the screenshot.
  // NOTE: shows the CURRENT logged-in user for every reel (fine while each
  // user only publishes their own listings on-device). For a true multi-author
  // feed, store author name/avatar on the Car at publish time and read `car`.
  String? _authorName;
  String? _authorAvatarUrl;

  // Purely-local "saved/bookmark" state (separate from real favorites).
  final Set<String> _saved = {};

  @override
  void initState() {
    super.initState();
    _loadAuthor();
  }

  Future<void> _loadAuthor() async {
    final user = FirebaseAuth.instance.currentUser;
    _authorName = (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName
        : null;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data();
        final url = data?['avatarUrl'] as String?;
        final name = data?['name'] as String?;
        if (url != null && url.isNotEmpty) _authorAvatarUrl = url;
        if (_authorName == null && name != null && name.isNotEmpty) {
          _authorName = name;
        }
      } catch (_) {/* offline / no doc — fall back to initials */}
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cars = context.watch<CarsProvider>().carsWithVideo;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // light status-bar icons over dark bg
      child: Scaffold(
        backgroundColor: Colors.black,
        body: cars.isEmpty
            ? const _EmptyVideoState()
            : PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: cars.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final car = cars[index];
                  return _VideoReel(
                    key: ValueKey(car.id),
                    car: car,
                    isActive: index == _currentPage,
                    muted: _muted,
                    onToggleMute: () => setState(() => _muted = !_muted),
                    authorName: _authorName,
                    authorAvatarUrl: _authorAvatarUrl,
                    saved: _saved.contains(car.id),
                    onToggleSave: () => setState(() {
                      if (_saved.contains(car.id)) {
                        _saved.remove(car.id);
                      } else {
                        _saved.add(car.id);
                      }
                    }),
                  );
                },
              ),
      ),
    );
  }
}

// ── Empty state (dark) ───────────────────────────────────────────────
class _EmptyVideoState extends StatelessWidget {
  const _EmptyVideoState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18.w,
            height: 18.w,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 7.h,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Пока нет видео',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Видеообзоры авто появятся здесь',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white.withOpacity(0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── A single full-screen reel ────────────────────────────────────────
class _VideoReel extends StatefulWidget {
  final Car car;
  final bool isActive;
  final bool muted;
  final VoidCallback onToggleMute;
  final String? authorName;
  final String? authorAvatarUrl;
  final bool saved;
  final VoidCallback onToggleSave;

  const _VideoReel({
    Key? key,
    required this.car,
    required this.isActive,
    required this.muted,
    required this.onToggleMute,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.saved,
    required this.onToggleSave,
  }) : super(key: key);

  @override
  State<_VideoReel> createState() => _VideoReelState();
}

class _VideoReelState extends State<_VideoReel> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasVideo = false;
  bool _subscribed = false;

  static const _accentBlue = Color(0xFF4DA6FF);

  // Placeholder engagement numbers for the demo UI — replace with real data.
  late final int _likeBase = 800 + (widget.car.id.hashCode.abs() % 24000);
  late final int _commentCount = 20 + (widget.car.id.hashCode.abs() % 900);
  late final int _saveBase = 100 + ((widget.car.id.hashCode.abs() ~/ 7) % 3000);

  @override
  void initState() {
    super.initState();
    _setupVideo();
  }

  // Autoplays as soon as the reel becomes the active page (i.e. when you
  // enter the video tab or swipe to it).
  void _setupVideo() {
    final path = widget.car.videoPath;
    final isNetwork = path != null && path.startsWith('http');
    _hasVideo = path != null &&
        path.isNotEmpty &&
        (isNetwork || File(path).existsSync());
    if (!_hasVideo) return;

    final c = isNetwork
        ? VideoPlayerController.networkUrl(Uri.parse(path!))
        : VideoPlayerController.file(File(path!));
    _controller = c;
    c.initialize().then((_) {
      if (!mounted) return;
      c.setLooping(true);
      c.setVolume(widget.muted ? 0.0 : 1.0); // respect global mute
      setState(() => _initialized = true);
      if (widget.isActive) c.play();
    }).catchError((_) {
      if (mounted) setState(() => _hasVideo = false);
    });
  }

  @override
  void didUpdateWidget(covariant _VideoReel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Play / pause when this reel becomes (in)active.
    if (widget.isActive != oldWidget.isActive &&
        _controller != null &&
        _initialized) {
      if (widget.isActive) {
        _controller!.play();
      } else {
        _controller!
          ..pause()
          ..seekTo(Duration.zero);
      }
    }

    // React to the global mute toggle.
    if (widget.muted != oldWidget.muted && _controller != null) {
      _controller!.setVolume(widget.muted ? 0.0 : 1.0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Tap the video to pause / resume. (Do the work first, then setState with
  // an empty body — pause()/play() return Futures and can't go inside setState.)
  void _togglePlay() {
    final c = _controller;
    if (c == null || !_initialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  Future<void> _openDetail() async {
    _controller?.pause();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CarDetailPage(car: widget.car)),
    );
    if (mounted && widget.isActive) _controller?.play();
  }

  void _soon(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Full video (contain → whole clip visible, black bars on the sides)
        GestureDetector(
          onTap: _hasVideo ? _togglePlay : _openDetail,
          child: _mediaLayer(),
        ),

        // 2. Center play indicator (visible only when paused)
        if (_hasVideo)
          IgnorePointer(child: Center(child: _centerPlay())),

        // 3. UI overlay (top icons + bottom content)
        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Column(
              children: [
                SizedBox(height: 0.5.h),
                _topBar(),
                const Spacer(),
                _bottomOverlay(car),
                SizedBox(height: 1.h),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Media ───────────────────────────────────────────────────────
  Widget _mediaLayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black), // black letterbox behind the video
        if (_hasVideo && _initialized && _controller != null)
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!), // full video, nothing cropped
            ),
          )
        else
          _poster(),
        if (_hasVideo && !_initialized)
          const Center(
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
        // Top + bottom scrims so overlay text/icons stay readable.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.45),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.75),
                ],
                stops: const [0.0, 0.18, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _poster() {
    final photos = widget.car.photoPaths;
    if (photos.isEmpty) return Container(color: const Color(0xFF111111));
    // Poster shown full too (contain), so nothing is cut off.
    return Center(child: _image(photos.first, fit: BoxFit.contain));
  }

  Widget _image(String path, {BoxFit fit = BoxFit.cover}) {
    Widget fallback() => Container(color: const Color(0xFF111111));
    if (path.startsWith('http')) {
      return Image.network(path, fit: fit, errorBuilder: (_, __, ___) => fallback());
    }
    final isFile = path.startsWith('/') || File(path).existsSync();
    if (isFile) {
      return Image.file(File(path), fit: fit, errorBuilder: (_, __, ___) => fallback());
    }
    return Image.asset(path, fit: fit, errorBuilder: (_, __, ___) => fallback());
  }

  Widget _centerPlay() {
    final playing = _controller?.value.isPlaying ?? false;
    return AnimatedOpacity(
      opacity: playing ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 17.w,
        height: 17.w,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 9.w),
      ),
    );
  }

  // ── Top bar (mute + search + menu) ──────────────────────────────
  Widget _topBar() {
    return Row(
      children: [
        const Spacer(),
        _iconBtn(
          widget.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          widget.onToggleMute,
        ),
        SizedBox(width: 3.w),
        _iconBtn(Icons.search, () => _soon('Поиск скоро')),
        SizedBox(width: 3.w),
        _iconBtn(Icons.more_vert, () => _soon('Меню скоро')),
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(
        icon,
        color: Colors.white,
        size: 3.2.h,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
      ),
    );
  }

  // ── Bottom overlay (text block + rail, then the info card) ───────
  Widget _bottomOverlay(Car car) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _textBlock(car)),
            SizedBox(width: 3.w),
            _actionRail(car),
          ],
        ),
        SizedBox(height: 1.6.h),
        _infoCard(car),
      ],
    );
  }

  Widget _textBlock(Car car) {
    final primary = _specsPrimary(car);
    final secondary = _specsSecondary(car);
    return GestureDetector(
      onTap: _openDetail,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _creatorRow(),
          SizedBox(height: 1.2.h),
          Text(
            car.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.2,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
          if (primary.isNotEmpty) ...[
            SizedBox(height: 0.7.h),
            Text(
              primary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12.5.sp,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ],
          if (secondary.isNotEmpty) ...[
            SizedBox(height: 0.2.h),
            Text(
              secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12.5.sp,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ],
          SizedBox(height: 0.6.h),
          Text(
            _hashtags(car),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _accentBlue,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _creatorRow() {
    final name = (widget.authorName != null && widget.authorName!.isNotEmpty)
        ? widget.authorName!
        : 'Автор';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final hasAvatar =
        widget.authorAvatarUrl != null && widget.authorAvatarUrl!.isNotEmpty;
    return Row(
      children: [
        Container(
          width: 9.w,
          height: 9.w,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.4),
            image: hasAvatar
                ? DecorationImage(
                    image: NetworkImage(widget.authorAvatarUrl!),
                    fit: BoxFit.cover)
                : null,
          ),
          child: hasAvatar
              ? null
              : Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.sp),
                  ),
                ),
        ),
        SizedBox(width: 2.5.w),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        ),
        SizedBox(width: 1.w),
        Icon(Icons.verified_rounded, size: 1.9.h, color: _accentBlue),
        SizedBox(width: 2.w),
        GestureDetector(
          onTap: () => setState(() => _subscribed = !_subscribed),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.7.h),
            decoration: BoxDecoration(
              color: _subscribed ? Colors.transparent : Colors.white,
              borderRadius: BorderRadius.circular(6.w),
              border: Border.all(color: Colors.white, width: 1.4),
            ),
            child: Text(
              _subscribed ? 'Вы подписаны' : 'Подписаться',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: _subscribed ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Right action rail ───────────────────────────────────────────
  Widget _actionRail(Car car) {
    final fav = context.watch<FavoritesProvider>().isFavorite(car);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _railButton(
          icon: fav ? Icons.thumb_up_rounded : Icons.thumb_up_off_alt_rounded,
          color: fav ? _accentBlue : Colors.white,
          text: _fmtCount(_likeBase + (fav ? 1 : 0)),
          onTap: () => context.read<FavoritesProvider>().toggleFavorite(car),
        ),
        SizedBox(height: 2.2.h),
        _railButton(
          icon: Icons.mode_comment_rounded,
          color: Colors.white,
          text: _fmtCount(_commentCount),
          onTap: _openDetail,
        ),
        SizedBox(height: 2.2.h),
        _railButton(
          icon: Icons.reply_rounded,
          color: Colors.white,
          text: 'Поделиться',
          onTap: () => _soon('Скоро можно будет делиться объявлением'),
        ),
        SizedBox(height: 2.2.h),
        _railButton(
          icon: widget.saved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          color: Colors.white,
          text: _fmtCount(_saveBase + (widget.saved ? 1 : 0)),
          onTap: widget.onToggleSave,
        ),
        SizedBox(height: 2.2.h),
        _railThumb(),
      ],
    );
  }

  Widget _railButton({
    required IconData icon,
    required Color color,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 3.6.h,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
          SizedBox(height: 0.5.h),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _railThumb() {
    return GestureDetector(
      onTap: _openDetail,
      child: Container(
        width: 11.w,
        height: 11.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2.5.w),
          border: Border.all(color: Colors.white, width: 1.5),
          color: Colors.black26,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2.1.w),
          child: widget.car.photoPaths.isNotEmpty
              ? _image(widget.car.photoPaths.first)
              : Icon(Icons.directions_car_outlined,
                  color: Colors.white70, size: 2.6.h),
        ),
      ),
    );
  }

  // ── Frosted info card (tap → detail) ────────────────────────────
  Widget _infoCard(Car car) {
    return GestureDetector(
      onTap: _openDetail,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.5.w),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.all(3.5.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4.5.w),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2.5.w),
                      child: SizedBox(width: 13.w, height: 13.w, child: _thumb()),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            car.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                          SizedBox(height: 0.3.h),
                          Text(
                            _priceText(car),
                            style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: _accentBlue),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.white.withOpacity(0.7), size: 3.h),
                  ],
                ),
                SizedBox(height: 1.3.h),
                Container(height: 1, color: Colors.white.withOpacity(0.15)),
                SizedBox(height: 1.1.h),
                Row(
                  children: [
                    _stat(Icons.event_outlined, car.year, 'Год'),
                    _statDivider(),
                    _stat(Icons.speed_outlined, '${car.km} км', 'Пробег'),
                    _statDivider(),
                    _stat(Icons.local_gas_station_outlined,
                        '${car.engineCapacity} л', 'Объём'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb() {
    final photos = widget.car.photoPaths;
    if (photos.isEmpty) {
      return Container(
        color: Colors.white.withOpacity(0.12),
        child: Icon(Icons.directions_car_outlined,
            color: Colors.white54, size: 3.h),
      );
    }
    return _image(photos.first);
  }

  Widget _stat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 1.9.h, color: Colors.white),
              SizedBox(width: 1.w),
              Flexible(
                child: Text(
                  value.trim().isEmpty ? '—' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: 0.2.h),
          Text(label,
              style: TextStyle(
                  fontSize: 9.5.sp, color: Colors.white.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _statDivider() =>
      Container(width: 1, height: 3.5.h, color: Colors.white.withOpacity(0.15));

  // ── Text helpers ────────────────────────────────────────────────
  String _priceText(Car car) {
    final p = car.price.trim();
    if (p.isEmpty) return 'Цена не указана';
    return p.contains('\$') ? p : '\$$p';
  }

  String _specsPrimary(Car car) {
    final p = <String>[];
    if (car.engineCapacity.trim().isNotEmpty) p.add('${car.engineCapacity.trim()} л');
    if (car.fuelType.trim().isNotEmpty) p.add(car.fuelType.trim());
    if (car.driveType.trim().isNotEmpty) p.add(car.driveType.trim());
    return p.join('  •  ');
  }

  String _specsSecondary(Car car) {
    final p = <String>[];
    if (car.km.trim().isNotEmpty) p.add('Пробег: ${car.km.trim()} км');
    if (car.condition.trim().isNotEmpty) p.add(car.condition.trim());
    return p.join('  •  ');
  }

  String _hashtags(Car car) {
    final tags = <String>[];
    final brand = car.name.trim().split(RegExp(r'\s+')).first;
    if (brand.isNotEmpty) tags.add('#$brand');
    if (car.bodyType.trim().isNotEmpty) {
      tags.add('#${car.bodyType.trim().replaceAll(RegExp(r'\s+'), '')}');
    }
    if (car.fuelType.trim().isNotEmpty) {
      tags.add('#${car.fuelType.trim().replaceAll(RegExp(r'\s+'), '')}');
    }
    tags.add('#Авто');
    return tags.join(' ');
  }

  String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) {
      final v = n / 1000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}K';
    }
    return '$n';
  }
}