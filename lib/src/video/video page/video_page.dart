import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_app/src/pages/home/providers/subscribtion_provider.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:new_app/src/video/controller/main_tab_controller.dart';
import 'package:new_app/src/video/video%20page/comments/comments_sheet.dart';
import 'package:new_app/src/video/video%20page/page/video_analytics_page.dart';
import 'package:new_app/src/video/video%20page/profile/user_stats_page.dart';
import 'package:new_app/src/video/cache/video_cache.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/pages/car_detail_page.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';

class VideoPage extends StatefulWidget {
  /// Опционально: id авто, на которое нужно сразу открыть ленту
  /// (используется когда VideoPage создаётся ЗАНОВО отдельным push,
  /// например из UserStatsPage/VideoAnalyticsPage). Если null — открывается
  /// обычная лента с начала.
  ///
  /// ВАЖНО: когда VideoPage уже живёт постоянно внутри MainNavBar
  /// (обычный случай — таб "Видео"), initState отрабатывает только один
  /// раз при первом запуске приложения, поэтому переход на конкретное авто
  /// ИЗ ДРУГИХ ТАБОВ (например, "Смотреть в ленте" на CarDetailPage) идёт
  /// не через этот параметр, а через NavTabController.pendingVideoCarId —
  /// см. _maybeJumpToPendingCar ниже.
  final String? initialCarId;

  const VideoPage({Key? key, this.initialCarId}) : super(key: key);

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Прыжок к initialCarId делаем один раз, как только список загрузится.
  bool _didJumpToInitial = false;

  // Последний id из NavTabController.pendingVideoCarId, на который мы уже
  // прыгнули — чтобы не прыгать повторно на каждый build.
  String? _lastConsumedPendingCarId;

  bool _muted = false;

  // ВАЖНО: изначально false — иначе первый ролик стартует со звуком
  // до того, как VisibilityDetector сообщит реальную видимость страницы.
  bool _pageVisible = false;
  bool _appActive = true;
  bool get _pageActive => _pageVisible && _appActive;

  final Set<String> _saved = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hideKeyboardHard();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active != _appActive && mounted) {
      setState(() => _appActive = active);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  /// КЕШ: заранее качаем следующие 1-2 ролика после [index], чтобы
  /// свайп на следующее видео был без прогрузки.
  void _prefetchAround(List<Car> cars, int index) {
    for (var i = index + 1; i <= index + 2 && i < cars.length; i++) {
      VideoCache.prefetch(cars[i].videoPath);
    }
  }

  void _maybeJumpToInitialCar(List<Car> cars) {
    if (_didJumpToInitial) return;
    final targetId = widget.initialCarId;
    if (targetId == null || cars.isEmpty) {
      _didJumpToInitial = true;
      if (cars.isNotEmpty) _prefetchAround(cars, 0);
      return;
    }
    final index = cars.indexWhere((c) => c.id == targetId);
    _didJumpToInitial = true;
    _prefetchAround(cars, index < 0 ? 0 : index);
    if (index > 0) {
      // Ждём кадр, чтобы PageController уже был приаттачен к PageView.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(index);
        setState(() => _currentPage = index);
      });
    } else if (index == 0) {
      // БАГ-ФИКС (краш): метод вызывается ИЗ build(), поэтому setState
      // здесь запрещён — Flutter кидает "setState() called during build".
      // Просто присваиваем значение: build и так уже идёт с ним.
      _currentPage = 0;
    }
  }

  /// Реагирует на запрос перехода к конкретному авто из NavTabController
  /// (кнопка «Смотреть в ленте» на странице деталей и т.п.). В отличие от
  /// initialCarId, этот путь срабатывает даже когда VideoPage уже давно
  /// живёт внутри MainNavBar и её initState отработал один раз в самом
  /// начале — то есть именно тот случай, когда пользователь переключается
  /// СЮДА из другого таба.
  void _maybeJumpToPendingCar(List<Car> cars, String? carId) {
    if (carId == null || carId == _lastConsumedPendingCarId) return;
    if (cars.isEmpty) return;
    final index = cars.indexWhere((c) => c.id == carId);
    if (index < 0) return;

    _lastConsumedPendingCarId = carId;
    _prefetchAround(cars, index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
      setState(() => _currentPage = index);
      // Сбрасываем запрос — иначе следующий build ленты попытается
      // прыгнуть снова на то же авто.
      context.read<NavTabController>().clearPendingVideoCarId();
    });
  }

  /// Стрелка «назад» тапнута: возвращаем пользователя на CarDetailPage
  /// того авто, с которого он открыл ленту. Обычный push — точно так же,
  /// как при обычном тапе по карточке видео (_openDetail в _VideoReel).
  void _handleBackToDetail(Car car) {
    context.read<NavTabController>().clearCameFromDetail();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CarDetailPage(car: car)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cars = context.watch<CarsProvider>().carsWithVideo;
    final nav = context.watch<NavTabController>();
    _maybeJumpToInitialCar(cars);
    _maybeJumpToPendingCar(cars, nav.pendingVideoCarId);

    final backTargetCar = nav.cameFromDetailCar;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        // На этой странице нет полей ввода — клавиатура не должна
        // влиять на layout, даже если фокус случайно "просочился".
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            VisibilityDetector(
              key: const Key('video-page-visibility'),
              onVisibilityChanged: (info) {
                final visible = info.visibleFraction > 0.5;
                if (visible != _pageVisible) {
                  _pageVisible = visible;
                  if (visible) _hideKeyboardHard();
                  if (mounted) setState(() {});
                }
              },
              child: cars.isEmpty
                  ? const _EmptyVideoState()
                  : PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: cars.length,
                      onPageChanged: (i) {
                        setState(() => _currentPage = i);
                        // КЕШ: следующие ролики качаем заранее.
                        _prefetchAround(cars, i);
                      },
                      itemBuilder: (context, index) {
                        final car = cars[index];
                        return _VideoReel(
                          key: ValueKey(car.id),
                          car: car,
                          isActive: index == _currentPage,
                          pageActive: _pageActive,
                          muted: _muted,
                          onToggleMute: () => setState(() => _muted = !_muted),
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

            // Стрелка «назад» — появляется ТОЛЬКО когда лента была открыта
            // кнопкой «Смотреть в ленте» со страницы деталей авто. При
            // обычном открытии таба "Видео" через нижний бар её нет —
            // это же таб, а не отдельный экран.
            if (backTargetCar != null)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(4.w, 0.8.h, 0, 0),
                    child: _BackButton(
                      onTap: () => _handleBackToDetail(backTargetCar),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Кружок со стрелкой назад поверх видео — тот же визуальный язык,
/// что и у остальных иконок ленты (тень для читаемости на любом фоне).
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 4.6.h,
        height: 4.6.h,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: 2.6.h,
        ),
      ),
    );
  }
}

/// КЛАВИАТУРА: жёсткое скрытие. Одного unfocus() недостаточно, потому что
/// при возврате со страницы (pop) Flutter может ВОССТАНОВИТЬ фокус
/// последнего текстового поля — и клавиатура всплывает сама. Поэтому:
///  1) снимаем фокус сразу;
///  2) явно говорим платформе спрятать клавиатуру (TextInput.hide);
///  3) повторяем на следующем кадре — уже ПОСЛЕ того, как Flutter
///     попытался восстановить фокус.
void _hideKeyboardHard() {
  FocusManager.instance.primaryFocus?.unfocus();
  SystemChannels.textInput.invokeMethod('TextInput.hide');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  });
}

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

class _VideoReel extends StatefulWidget {
  final Car car;
  final bool isActive;
  final bool pageActive;
  final bool muted;
  final VoidCallback onToggleMute;
  final bool saved;
  final VoidCallback onToggleSave;

  const _VideoReel({
    Key? key,
    required this.car,
    required this.isActive,
    required this.pageActive,
    required this.muted,
    required this.onToggleMute,
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

  bool _uiHidden = false;

  // ── СКОРОСТЬ 2x ПРИ ДОЛГОМ НАЖАТИИ (как в TikTok) ────────────────────
  // Долгое нажатие: UI прячется + видео играет на 2x. Пока палец зажат,
  // можно вести его ВЛЕВО — вернётся обычная скорость, ВПРАВО — снова 2x.
  // Отпустил — всё возвращается как было.
  bool _longPressing = false;
  bool _fast = false;
  double _pressStartDx = 0;
  double _pressStartDy = 0;

  // ── ЗАКРЕПЛЁННАЯ 2x ─────────────────────────────────────────────────
  // Во время долгого нажатия ведёшь палец ВНИЗ — 2x «закрепляется»:
  // после отпускания видео ПРОДОЛЖАЕТ играть на 2x, UI возвращается,
  // сверху висит бейдж «2x». Отключить: долгое нажатие + палец ВВЕРХ,
  // или просто тап по бейджу.
  bool _speedLocked = false;

  // Позиция двойного тапа — сердце появляется там, где тапнул
  // пользователь, а не по центру экрана.
  Offset? _doubleTapPosition;

  late final AnimationController _likeAnim;

  static const _accentBlue = Color(0xFF4DA6FF);

  late final int _saveBase = 100 + ((widget.car.id.hashCode.abs() ~/ 7) % 3000);

  // ── АВТОР РОЛИКА ─────────────────────────────────────────────────────
  // БАГ-ФИКС: раньше имя/аватар брались из FirebaseAuth.currentUser —
  // то есть у КАЖДОГО видео показывался ТЕКУЩИЙ пользователь, а не тот,
  // кто опубликовал объявление. Теперь данные автора грузятся из
  // users/{car.ownerId} — для каждого ролика свои.
  String? _ownerName;
  String? _ownerAvatarUrl;

  // ----- Счётчик комментариев (комментарии + все ответы) -----
  // Работает БЕЗ collectionGroup и без индексов в консоли:
  // 1) стрим комментариев верхнего уровня (живое обновление);
  // 2) на каждый снапшот — агрегатный count() по подколлекции replies
  //    каждого комментария (читается только число, не документы);
  // 3) после закрытия шторки комментариев — принудительный пересчёт,
  //    т.к. новый ОТВЕТ не меняет верхний уровень и стрим его не видит.
  int _commentsTotal = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _commentsSub;
  int _recountGeneration = 0; // защита от гонки старых/новых пересчётов

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      FirebaseFirestore.instance
          .collection('cars')
          .doc(widget.car.id)
          .collection('comments');

  @override
  void initState() {
    super.initState();
    _likeAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850));
    _setupVideo();
    _loadOwner();

    context.read<CarsProvider>().loadLikeState(widget.car.id);
    context.read<SubscriptionsProvider>().loadSubscription(widget.car.ownerId);

    _commentsSub = _commentsRef.snapshots().listen(
      _recountFromSnapshot,
      onError: (_) {/* offline и т.п. — оставляем последнее значение */},
    );

    if (widget.isActive) {
      // Владелец, смотрящий своё же объявление, просмотр не увеличивает —
      // это проверяется внутри incrementView.
      context
          .read<CarsProvider>()
          .incrementView(widget.car.id, widget.car.ownerId);
    }
  }

  /// Загружаем имя и аватар ВЛАДЕЛЬЦА объявления (не текущего юзера).
  Future<void> _loadOwner() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.car.ownerId)
          .get();
      final data = doc.data();
      if (!mounted) return;
      setState(() {
        final name = (data?['name'] as String?)?.trim();
        final url = (data?['avatarUrl'] as String?)?.trim();
        _ownerName = (name != null && name.isNotEmpty) ? name : null;
        _ownerAvatarUrl = (url != null && url.isNotEmpty) ? url : null;
      });
    } catch (_) {
      // offline / нет документа — покажем «Автор» и инициалы
    }
  }

  Future<void> _recountFromSnapshot(
      QuerySnapshot<Map<String, dynamic>> snap) async {
    final generation = ++_recountGeneration;
    int total = snap.docs.length;
    await Future.wait(snap.docs.map((d) async {
      try {
        final agg = await d.reference.collection('replies').count().get();
        total += agg.count ?? 0;
      } catch (_) {
        // не критично — этот комментарий посчитаем без ответов
      }
    }));
    // Если за время подсчёта стартовал более свежий пересчёт — молчим.
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

  Future<void> _openComments() async {
    await CommentsSheet.show(context, widget.car.id);
    if (!mounted) return;
    // КЛАВИАТУРА: после закрытия шторки комментариев жёстко прячем
    // клавиатуру, чтобы поле ввода из шторки не «вернуло» её на видео.
    _hideKeyboardHard();
    // Пользователь мог добавить ответы — пересчитываем после закрытия.
    _refreshCommentsCount();
  }

  /// КЕШ: если сетевое видео уже скачано (prefetch со страницы деталей
  /// или предзагрузка соседних роликов) — играем локальный файл,
  /// старт мгновенный. Если нет — играем по сети и параллельно кешируем.
  Future<void> _setupVideo() async {
    final path = widget.car.videoPath;
    final isNetwork = path != null && path.startsWith('http');
    _hasVideo = path != null &&
        path.isNotEmpty &&
        (isNetwork || File(path).existsSync());
    if (!_hasVideo) return;

    VideoPlayerController c;
    if (isNetwork) {
      final cached = await VideoCache.cachedFile(path!);
      if (!mounted) return;
      if (cached != null) {
        c = VideoPlayerController.file(cached);
      } else {
        c = VideoPlayerController.networkUrl(Uri.parse(path));
        VideoCache.prefetch(path); // докачаем в фоне на следующий раз
      }
    } else {
      c = VideoPlayerController.file(File(path!));
    }

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
    if (widget.isActive && !oldWidget.isActive) {
      context
          .read<CarsProvider>()
          .incrementView(widget.car.id, widget.car.ownerId);
    }
    if (widget.muted != oldWidget.muted && _controller != null) {
      _controller!.setVolume(widget.muted ? 0.0 : 1.0);
    }
  }

  @override
  void dispose() {
    _commentsSub?.cancel();
    _likeAnim.dispose();
    _controller?.dispose();
    super.dispose();
  }

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

  /// Лайк синхронизирован с «Избранным»: лайкнул на видео — авто появляется
  /// на странице избранного, снял лайк — убирается оттуда. Работает одинаково
  /// и здесь, и на странице деталей.
  void _toggleLikeSynced() {
    final cars = context.read<CarsProvider>();
    final favs = context.read<FavoritesProvider>();
    final willLike = !cars.isLikedByMe(widget.car.id);
    cars.toggleLike(widget.car.id);
    if (favs.isFavorite(widget.car) != willLike) {
      favs.toggleFavorite(widget.car);
    }
  }

  void _onDoubleTap() {
    if (!context.read<CarsProvider>().isLikedByMe(widget.car.id)) {
      _toggleLikeSynced();
    }
    _likeAnim.forward(from: 0);
  }

  Future<void> _openDetail() async {
    _hideKeyboardHard();
    _controller?.pause();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CarDetailPage(car: widget.car)),
    );
    if (!mounted) return;
    // КЛАВИАТУРА (баг-фикс): при возврате со страницы деталей Flutter мог
    // восстановить фокус текстового поля и клавиатура всплывала сама.
    // Жёстко прячем её и повторяем на следующем кадре.
    _hideKeyboardHard();
    _syncPlayback();
  }

  /// Тап по аватару/имени автора → публичная страница автора:
  /// его публикации + общая статистика.
  Future<void> _openProfile() async {
    _hideKeyboardHard();
    _controller?.pause();
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => UserStatsPage(uid: widget.car.ownerId)),
    );
    if (!mounted) return;
    _hideKeyboardHard();
    _syncPlayback();
  }

  /// «Аналитика» на СВОЁМ видео → аналитика ИМЕННО ЭТОГО видео:
  /// кто лайкнул, кто смотрел, когда опубликовано, просмотры за сегодня.
  Future<void> _openVideoAnalytics() async {
    _hideKeyboardHard();
    _controller?.pause();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoAnalyticsPage(car: widget.car)),
    );
    if (!mounted) return;
    _hideKeyboardHard();
    _syncPlayback();
  }

  void _soon(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

  // ------------------------------------------------- long press 2x speed

  void _onLongPressStart(LongPressStartDetails d) {
    _pressStartDx = d.localPosition.dx;
    _pressStartDy = d.localPosition.dy;
    setState(() {
      _uiHidden = true;
      _longPressing = true;
    });
    if (_hasVideo && _initialized) _applySpeed(true);
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d) {
    if (!_longPressing || !_hasVideo || !_initialized) return;
    final dx = d.localPosition.dx - _pressStartDx;
    final dy = d.localPosition.dy - _pressStartDy;

    // ВНИЗ более чем на 60px — закрепляем 2x (останется после отпускания).
    // ВВЕРХ более чем на 60px — снимаем закрепление.
    if (!_speedLocked && dy > 60) {
      _speedLocked = true;
      HapticFeedback.mediumImpact();
      _applySpeed(true);
      return;
    }
    if (_speedLocked && dy < -60) {
      _speedLocked = false;
      HapticFeedback.lightImpact();
      _applySpeed(false);
      return;
    }
    if (_speedLocked) return; // закреплено — горизонталь не трогаем

    // Увёл палец влево более чем на 50px — обычная скорость.
    // Вернул вправо — снова 2x. Гистерезис, чтобы не дёргалось на границе.
    if (_fast && dx < -50) {
      _applySpeed(false);
    } else if (!_fast && dx > -20) {
      _applySpeed(true);
    }
  }

  void _applySpeed(bool fast) {
    _fast = fast;
    _controller?.setPlaybackSpeed(fast ? 2.0 : 1.0);
    if (mounted) setState(() {});
  }

  void _onLongPressFinish() {
    // Если 2x закреплена свайпом вниз — НЕ сбрасываем скорость:
    // видео продолжает играть на 2x с бейджем сверху.
    if (!_speedLocked) {
      if (_hasVideo && _initialized) _controller?.setPlaybackSpeed(1.0);
      _fast = false;
    }
    if (mounted) {
      setState(() {
        _uiHidden = false;
        _longPressing = false;
      });
    }
  }

  /// Снять закреплённую 2x (тап по бейджу).
  void _unlockSpeed() {
    if (!_speedLocked) return;
    _speedLocked = false;
    HapticFeedback.lightImpact();
    _applySpeed(false);
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _hasVideo ? _togglePlay : _openDetail,
          onDoubleTapDown: (details) =>
              _doubleTapPosition = details.localPosition,
          onDoubleTap: _onDoubleTap,
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMove,
          onLongPressEnd: (_) => _onLongPressFinish(),
          onLongPressCancel: _onLongPressFinish,
          child: _mediaLayer(),
        ),

        if (_hasVideo && !_uiHidden)
          IgnorePointer(child: Center(child: _centerPlay())),

        _likeBurst(),

        // Индикатор скорости при долгом нажатии (2x / обычная + подсказка).
        if (_longPressing && _hasVideo && _initialized) _speedOverlay(),

        // Закреплённая 2x: палец отпущен, UI виден, видео играет на 2x.
        // Бейдж сверху — тап по нему выключает.
        if (_speedLocked && !_longPressing && _hasVideo && _initialized)
          _lockedSpeedBadge(),

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

  Widget _mediaLayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        if (_hasVideo && _initialized && _controller != null)
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          )
        else
          _poster(),
        if (_hasVideo && !_initialized)
          const Center(
            child:
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
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
      return Image.network(path,
          fit: fit, errorBuilder: (_, __, ___) => fallback());
    }
    final isFile = path.startsWith('/') || File(path).existsSync();
    if (isFile) {
      return Image.file(File(path),
          fit: fit, errorBuilder: (_, __, ___) => fallback());
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

  // Сердце появляется в точке двойного тапа, а не по центру экрана.
  //
  // БАГ-ФИКС ("Incorrect use of ParentDataWidget"): Positioned обязан быть
  // ПРЯМЫМ ребёнком Stack. Раньше между ними стояли IgnorePointer и
  // AnimatedBuilder — Flutter ругался каждый кадр анимации. Теперь снаружи
  // Positioned.fill (он прямой ребёнок Stack), а сердце позиционируем
  // через Transform.translate внутри.
  Widget _likeBurst() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _likeAnim,
          builder: (_, __) {
            final v = _likeAnim.value;
            final position = _doubleTapPosition;
            if (v == 0 || position == null) return const SizedBox.shrink();
            final scale = 0.5 +
                Curves.easeOutBack.transform((v * 1.6).clamp(0.0, 1.0)) * 0.7;
            final opacity = v < 0.65 ? 1.0 : (1 - (v - 0.65) / 0.35);
            const iconSize = 90.0;
            return Align(
              alignment: Alignment.topLeft,
              child: Transform.translate(
                offset: Offset(
                  (position.dx - iconSize / 2).clamp(0.0, double.infinity),
                  (position.dy - iconSize / 2).clamp(0.0, double.infinity),
                ),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: iconSize,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 18)],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Индикатор при долгом нажатии: сверху бейдж «2x» (или «Обычная»)
  /// и подсказка, куда вести палец, чтобы сменить скорость.
  Widget _speedOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 1.2.h),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
                decoration: BoxDecoration(
                  color: _fast
                      ? Colors.white.withOpacity(0.92)
                      : Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(3.h),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.4), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _fast
                          ? Icons.fast_forward_rounded
                          : Icons.play_arrow_rounded,
                      size: 2.4.h,
                      color: _fast ? Colors.black : Colors.white,
                    ),
                    SizedBox(width: 1.5.w),
                    Text(
                      _fast ? 'Скорость 2x' : 'Обычная скорость',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w800,
                        color: _fast ? Colors.black : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 0.8.h),
              Text(
                _speedLocked
                    ? '2x закреплена · веди палец вверх — отключить'
                    : _fast
                        ? 'Влево — обычная · Вниз — закрепить 2x'
                        : 'Вправо — 2x · Вниз — закрепить 2x',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.85),
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Бейдж закреплённой 2x: висит сверху, пока скорость закреплена.
  /// Виден вместе со всем остальным UI (лайки, комментарии и т.д.).
  /// Тап по бейджу — выключить и вернуться к обычной скорости.
  Widget _lockedSpeedBadge() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 1.2.h),
            GestureDetector(
              onTap: _unlockSpeed,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.7.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(3.h),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fast_forward_rounded,
                        size: 2.2.h, color: Colors.black),
                    SizedBox(width: 1.5.w),
                    Text(
                      '2x',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Container(
                        width: 1,
                        height: 1.8.h,
                        color: Colors.black.withOpacity(0.15)),
                    SizedBox(width: 2.w),
                    Icon(Icons.close_rounded,
                        size: 2.h, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const Spacer(),
        _iconBtn(
          widget.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          widget.onToggleMute,
        ),
        SizedBox(width: 3.w),
        _iconBtn(
          Icons.search,
          // Переключаем таб на "Поиск", а не push — тогда SearchPage
          // открывается внутри MainNavBar и нижняя навигация остаётся видна.
          () => context.read<NavTabController>().setIndex(1),
        ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _creatorRow(car),
        SizedBox(height: 1.2.h),
        GestureDetector(
          onTap: _openDetail,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 6)
                    ],
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
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 6)
                    ],
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
        ),
      ],
    );
  }

  Widget _creatorRow(Car car) {
    // Имя и аватар — ВЛАДЕЛЬЦА объявления (загружены в _loadOwner),
    // а не текущего пользователя.
    final name = _ownerName ?? 'Автор';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final hasAvatar = _ownerAvatarUrl != null && _ownerAvatarUrl!.isNotEmpty;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMyOwnCar = myUid != null && myUid == car.ownerId;
    final subscribed =
        context.watch<SubscriptionsProvider>().isSubscribed(car.ownerId);
    final pending =
        context.watch<SubscriptionsProvider>().isPending(car.ownerId);

    return Row(
      children: [
        // Тап по аватару/имени открывает страницу автора:
        // его публикации + общая статистика.
        GestureDetector(
          onTap: _openProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
                          image: NetworkImage(_ownerAvatarUrl!),
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
            ],
          ),
        ),
        SizedBox(width: 2.w),
        if (isMyOwnCar)
          // СВОЁ видео: вместо «Подписаться» — кнопка «Аналитика»,
          // которая открывает аналитику ИМЕННО ЭТОГО видео
          // (кто лайкнул, кто смотрел, когда опубликовано).
          GestureDetector(
            onTap: _openVideoAnalytics,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.7.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6.w),
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 1.9.h, color: Colors.black),
                  SizedBox(width: 1.w),
                  Text(
                    'Аналитика',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GestureDetector(
            onTap: pending
                ? null
                : () => context
                    .read<SubscriptionsProvider>()
                    .toggleSubscribe(car.ownerId),
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
          // Лайк также добавляет/убирает авто из «Избранного».
          onTap: _toggleLikeSynced,
        ),
        SizedBox(height: 2.2.h),
        // Реальный счётчик: комментарии верхнего уровня + ВСЕ ответы.
        _railButton(
          icon: Icons.mode_comment_rounded,
          color: Colors.white,
          text: _fmtCount(_commentsTotal),
          onTap: _openComments,
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
                      child:
                          SizedBox(width: 13.w, height: 13.w, child: _thumb()),
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

  String _priceText(Car car) {
    final p = car.price.trim();
    if (p.isEmpty) return 'Цена не указана';
    return p.contains('\$') ? p : '\$$p';
  }

  String _specsPrimary(Car car) {
    final p = <String>[];
    if (car.engineCapacity.trim().isNotEmpty) {
      p.add('${car.engineCapacity.trim()} л');
    }
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