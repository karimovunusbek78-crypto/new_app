import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_app/src/pages/home/providers/subscribtion_provider.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/pages/car_detail_page.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({Key? key}) : super(key: key);

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Global sound toggle — stays consistent as you swipe between reels.
  bool _muted = false;

  // Playback gates: only play when the page is on screen AND the app is
  // in the foreground.
  bool _pageVisible = true;
  bool _appActive = true;
  bool get _pageActive => _pageVisible && _appActive;

  // Author (publisher) info pulled straight from the profile.
  String? _authorName;
  String? _authorAvatarUrl;

  // Purely-local "saved/bookmark" state (separate from real favorites).
  final Set<String> _saved = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAuthor();
    // Kill any keyboard left focused by a previous screen (e.g. the publish form).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active != _appActive && mounted) {
      setState(() => _appActive = active);
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cars = context.watch<CarsProvider>().carsWithVideo;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: VisibilityDetector(
          key: const Key('video-page-visibility'),
          onVisibilityChanged: (info) {
            final visible = info.visibleFraction > 0.5;
            if (visible != _pageVisible) {
              _pageVisible = visible;
              if (visible) FocusManager.instance.primaryFocus?.unfocus();
              if (mounted) setState(() {});
            }
          },
          child: cars.isEmpty
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
                      pageActive: _pageActive,
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
  final bool pageActive;
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
    required this.pageActive,
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

class _VideoReelState extends State<_VideoReel>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasVideo = false;

  // Hold-to-watch-clean: hides all overlays while pressing.
  bool _uiHidden = false;

  // Center heart animation on double-tap.
  late final AnimationController _likeAnim;

  static const _accentBlue = Color(0xFF4DA6FF);

  // Placeholder engagement numbers — comments/share/save aren't wired up yet.
  late final int _commentCount = 20 + (widget.car.id.hashCode.abs() % 900);
  late final int _saveBase = 100 + ((widget.car.id.hashCode.abs() ~/ 7) % 3000);

  @override
  void initState() {
    super.initState();
    _likeAnim =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
    _setupVideo();

    // Подтягиваем реальное состояние лайка/подписки из Firestore.
    context.read<CarsProvider>().loadLikeState(widget.car.id);
    context.read<SubscriptionsProvider>().loadSubscription(widget.car.ownerId);

    // Если карточка сразу активна при первом построении — засчитываем просмотр.
    if (widget.isActive) {
      context.read<CarsProvider>().incrementView(widget.car.id);
    }
  }

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
      c.setVolume(widget.muted ? 0.0 : 1.0);
      setState(() => _initialized = true);
      _syncPlayback();
    }).catchError((_) {
      if (mounted) setState(() => _hasVideo = false);
    });
  }

  // Plays only when this reel is the active page AND the page is visible.
  void _syncPlayback() {
    final c = _controller;
    if (c == null || !_initialized) return;
    final shouldPlay = widget.isActive && widget.pageActive;
    if (shouldPlay) {
      if (!c.value.isPlaying) c.play();
    } else {
      if (c.value.isPlaying) c.pause();
      if (!widget.isActive) c.seekTo(Duration.zero);
    }
  }

  @override
  void didUpdateWidget(covariant _VideoReel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive ||
        widget.pageActive != oldWidget.pageActive) {
      _syncPlayback();
    }
    // Засчитываем просмотр каждый раз, когда реел становится активным.
    if (widget.isActive && !oldWidget.isActive) {
      context.read<CarsProvider>().incrementView(widget.car.id);
    }
    if (widget.muted != oldWidget.muted && _controller != null) {
      _controller!.setVolume(widget.muted ? 0.0 : 1.0);
    }
  }

  @override
  void dispose() {
    _likeAnim.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // Tap the video to pause / resume.
  void _togglePlay() {
    FocusManager.instance.primaryFocus?.unfocus();
    final c = _controller;
    if (c == null || !_initialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  // Double-tap → like (never unlikes) + heart burst.
  void _onDoubleTap() {
    final cars = context.read<CarsProvider>();
    if (!cars.isLikedByMe(widget.car.id)) {
      cars.toggleLike(widget.car.id);
    }
    _likeAnim.forward(from: 0);
  }

  Future<void> _openDetail() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _controller?.pause();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CarDetailPage(car: widget.car)),
    );
    if (mounted) _syncPlayback();
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
        // 1. Full video + gestures (tap = pause, double = like, hold = clean)
        GestureDetector(
          onTap: _hasVideo ? _togglePlay : _openDetail,
          onDoubleTap: _onDoubleTap,
          onLongPressStart: (_) => setState(() => _uiHidden = true),
          onLongPressEnd: (_) => setState(() => _uiHidden = false),
          onLongPressCancel: () => setState(() => _uiHidden = false),
          child: _mediaLayer(),
        ),

        // 2. Center play indicator (only when paused, and UI visible)
        if (_hasVideo && !_uiHidden)
          IgnorePointer(child: Center(child: _centerPlay())),

        // 3. Double-tap heart burst (always available, above the video)
        _likeBurst(),

        // 4. UI overlay — fades out while holding to watch clean.
        IgnorePointer(
          ignoring: _uiHidden,
          child: AnimatedOpacity(
            opacity: _uiHidden ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: SafeArea(
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
        // Scrims fade with the UI so holding gives a fully clean view.
        AnimatedOpacity(
          opacity: _uiHidden ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
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
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _poster() {
    final photos = widget.car.photoPaths;
    if (photos.isEmpty) return Container(color: const Color(0xFF111111));
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

  Widget _likeBurst() {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _likeAnim,
          builder: (_, __) {
            final v = _likeAnim.value;
            if (v == 0) return const SizedBox.shrink();
            final scale =
                0.5 + Curves.easeOutBack.transform((v * 1.6).clamp(0.0, 1.0)) * 0.7;
            final opacity = v < 0.65 ? 1.0 : (1 - (v - 0.65) / 0.35);
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 30.w,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 18)],
                ),
              ),
            );
          },
        ),
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
          _creatorRow(car),
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

  Widget _creatorRow(Car car) {
    final name = (widget.authorName != null && widget.authorName!.isNotEmpty)
        ? widget.authorName!
        : 'Автор';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final hasAvatar =
        widget.authorAvatarUrl != null && widget.authorAvatarUrl!.isNotEmpty;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMyOwnCar = myUid != null && myUid == car.ownerId;
    final subscribed = context.watch<SubscriptionsProvider>().isSubscribed(car.ownerId);

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
        // Нельзя подписаться на самого себя.
        if (!isMyOwnCar)
          GestureDetector(
            onTap: () => context.read<SubscriptionsProvider>().toggleSubscribe(car.ownerId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.7.h),
              decoration: BoxDecoration(
                color: subscribed ? Colors.transparent : Colors.white,
                borderRadius: BorderRadius.circular(6.w),
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              child: Text(
                subscribed ? 'Вы подписаны' : 'Подписаться',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: subscribed ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Right action rail ───────────────────────────────────────────
  Widget _actionRail(Car car) {
    final cars = context.watch<CarsProvider>();
    final liked = cars.isLikedByMe(car.id);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _railButton(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: liked ? Colors.red : Colors.white,
          text: _fmtCount(car.likesCount),
          onTap: () => context.read<CarsProvider>().toggleLike(car.id),
        ),
        SizedBox(height: 2.2.h),
        _railButton(
          icon: Icons.mode_comment_rounded,
          color: Colors.white,
          text: _fmtCount(_commentCount), // заглушка
          onTap: _openDetail,
        ),
        SizedBox(height: 2.2.h),
        _railButton(
          icon: Icons.reply_rounded,
          color: Colors.white,
          text: 'Поделиться', // заглушка
          onTap: () => _soon('Скоро можно будет делиться объявлением'),
        ),
        SizedBox(height: 2.2.h),
        _railButton(
          icon: widget.saved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          color: Colors.white,
          text: _fmtCount(_saveBase + (widget.saved ? 1 : 0)), // заглушка
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
                    _stat(Icons.remove_red_eye_outlined,
                        _fmtCount(car.viewsCount), 'Просмотры'),
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