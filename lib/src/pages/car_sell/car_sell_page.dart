import 'package:flutter/material.dart';
import 'package:new_app/src/pages/autoslon/permission/publish_permission.dart';
import 'package:new_app/src/pages/car_sell/car_publish/car_publish_page.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

// NOTE: CarSellPermissionNotifier now lives in publish_permissions.dart.
// Make sure it is registered in your Provider tree, e.g.:
//   ChangeNotifierProvider(create: (_) => CarSellPermissionNotifier()),
//
// This page now ONLY handles the access-request flow (none / waiting /
// loading). Once permission is granted it pushes [CarPublishPage], which
// owns the actual publish form. Whatever [CarPublishPage] returns (the new
// [Car], or null if the user backs out) is then passed straight back up by
// popping this page with the same result — so callers of [CarSellPage]
// keep working exactly as before.

class CarSellPage extends StatefulWidget {
  const CarSellPage({Key? key}) : super(key: key);

  @override
  State<CarSellPage> createState() => _CarSellPageState();
}

class _CarSellPageState extends State<CarSellPage>
    with TickerProviderStateMixin {
  // Accent colors
  static const _accentDark = Color(0xFF111111);
  static const _accentBlue = Color(0xFF5B4FD9);

  // Your contact details
  static const _whatsappNumber = '996555510225';
  static const _phoneNumber = '+996555510225';
  static const _telegramHandle = '@fahriddin151515';

  // ── Animation Controllers ─────────────────────────────────────
  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  late final AnimationController _slideController;
  late final AnimationController _pulseController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Guards against pushing CarPublishPage more than once while granted.
  bool _navigatedToPublish = false;

  // Per-card entrance controllers, created ONCE up front (not on every
  // build) and disposed in dispose(). Indexed by the `order` passed to
  // _animatedContactCard. We never have more than 3 contact cards visible
  // at a time (waiting view uses 2, permission view uses 3), so 3 is enough
  // — _animatedContactCard reuses controller[order] regardless of which
  // view is showing.
  static const _contactCardCount = 3;
  late final List<AnimationController> _contactCardControllers;
  late final List<Animation<double>> _contactCardAnimations;

  @override
  void initState() {
    super.initState();

    // Fade animation (0-600ms)
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    // Scale animation (200-1000ms)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Slide animation for cards (300-1200ms)
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Pulse animation (1300ms, repeating)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Contact-card entrance controllers — created once here, reused by
    // _animatedContactCard on every build instead of being recreated.
    _contactCardControllers = List.generate(
      _contactCardCount,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      ),
    );
    _contactCardAnimations = List.generate(_contactCardCount, (order) {
      final startDelay = (order * 100).toDouble();
      final start = (startDelay / 1000).clamp(0.0, 0.6);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _contactCardControllers[order],
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    // Start animations
    _fadeController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scaleController.forward();
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _slideController.forward();
        });
        for (final c in _contactCardControllers) {
          c.forward();
        }
      }
    });

    // Start listening to the permission document (live updates). When the
    // admin grants access, the Consumer below moves on to CarPublishPage
    // on its own.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CarSellPermissionNotifier>().start();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    for (final c in _contactCardControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // Records the permission request (call when a contact button is tapped).
  void _request() {
    if (!mounted) return;
    context.read<CarSellPermissionNotifier>().requestPermission();
  }

  // Opens WhatsApp with user's ID pre-filled.
  Future<void> _openWhatsApp() async {
    _request();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final text =
        Uri.encodeComponent('Хочу разрешение на публикацию. Мой ID: $uid');
    final url = Uri.parse('https://wa.me/$_whatsappNumber?text=$text');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть WhatsApp')),
        );
      }
    }
  }

  // Opens Telegram
  Future<void> _openTelegram() async {
    _request();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final url = Uri.parse('https://t.me/automarket_support?text=Мой ID: $uid');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть Telegram')),
        );
      }
    }
  }

  // Pushes the dedicated publish form once permission is granted, then
  // forwards whatever it returns back to whoever opened CarSellPage.
  Future<void> _goToPublishPage() async {
    if (_navigatedToPublish) return;
    _navigatedToPublish = true;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CarPublishPage()),
    );

    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<CarSellPermissionNotifier>(
          builder: (context, notifier, _) {
            switch (notifier.state) {
              case PublishPermissionState.loading:
                return _buildLoadingScreen();
              case PublishPermissionState.granted:
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _goToPublishPage());
                return _buildLoadingScreen();
              case PublishPermissionState.waiting:
                return _buildWaitingView();
              case PublishPermissionState.none:
                return _buildPermissionView();
            }
          },
        ),
      ),
    );
  }

  // ── Loading screen ────────────────────────────────────────────
  Widget _buildLoadingScreen() {
    return Center(
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: SizedBox(
          width: 5.h,
          height: 5.h,
          child: const CircularProgressIndicator(
            strokeWidth: 3,
            color: _accentBlue,
          ),
        ),
      ),
    );
  }

  // ── Waiting for approval screen ────────────────────────────────
  Widget _buildWaitingView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: Column(
          children: [
            // Back button
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Padding(
                  padding: EdgeInsets.only(left: 5.w, top: 1.h, bottom: 2.h),
                  child:
                      Icon(Icons.arrow_back, color: _accentDark, size: 3.2.h),
                ),
              ),
            ),

            // Hourglass hero icon (pulsing)
            ScaleTransition(
              scale: _scaleAnimation,
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 25.w,
                  height: 25.w,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE8E5F7), Color(0xFFF0ECFF)],
                    ),
                    borderRadius: BorderRadius.circular(8.w),
                    boxShadow: [
                      BoxShadow(
                        color: _accentBlue.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(Icons.hourglass_top_rounded,
                      color: _accentBlue, size: 14.w),
                ),
              ),
            ),

            SizedBox(height: 3.h),

            // Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              child: Text(
                'Заявка отправлена',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                  color: _accentDark,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            SizedBox(height: 1.h),

            // Subtitle
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: Text(
                'Мы получили вашу заявку. Как только мы подтвердим доступ, '
                'форма публикации откроется автоматически.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF9A9AA0),
                  height: 1.5,
                ),
              ),
            ),

            SizedBox(height: 3.h),

            // Live status row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 2.h,
                  height: 2.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: _accentBlue,
                  ),
                ),
                SizedBox(width: 2.w),
                Text(
                  'Ожидаем подтверждения…',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: _accentBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            SizedBox(height: 3.h),

            // Follow-up contact options
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Хотите ускорить?',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: _accentDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 1.5.h),
                  _animatedContactCard(
                    order: 0,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Написать в WhatsApp',
                    subtitle: _phoneNumber,
                    onTap: _openWhatsApp,
                    badgeColor: Colors.green,
                  ),
                  SizedBox(height: 1.5.h),
                  _animatedContactCard(
                    order: 1,
                    icon: Icons.send_rounded,
                    title: 'Написать в Telegram',
                    subtitle: _telegramHandle,
                    onTap: _openTelegram,
                    badgeColor: const Color(0xFF0088CC),
                  ),
                ],
              ),
            ),

            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  // ── Permission required screen ─────────────────────────────────
  Widget _buildPermissionView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: Column(
          children: [
            // Back button with fade
            FadeTransition(
              opacity: _fadeAnimation,
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Padding(
                    padding: EdgeInsets.only(left: 5.w, top: 1.h, bottom: 2.h),
                    child: Icon(Icons.arrow_back,
                        color: _accentDark, size: 3.2.h),
                  ),
                ),
              ),
            ),
            // Hero icon with scale + pulse
            ScaleTransition(
              scale: _scaleAnimation,
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 25.w,
                  height: 25.w,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE8E5F7), Color(0xFFF0ECFF)],
                    ),
                    borderRadius: BorderRadius.circular(8.w),
                    boxShadow: [
                      BoxShadow(
                        color: _accentBlue.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    color: _accentBlue,
                    size: 14.w,
                  ),
                ),
              ),
            ),

            SizedBox(height: 3.h),

            // Title with fade + slide
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5.w),
                  child: Text(
                    'Продайте ваше авто',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      color: _accentDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 1.h),

            // Subtitle with fade + slide
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: Text(
                    'Разместите объявление и получите больше клиентов',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF9A9AA0),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 4.h),

            // Contact section header
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Свяжитесь с нами',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: _accentDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      Text(
                        'Чтобы разместить объявление, нужно разрешение. Свяжитесь с нами через удобный канал.',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF9A9AA0),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 3.h),

            // Contact cards with staggered animation
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              child: Column(
                children: [
                  _animatedContactCard(
                    order: 0,
                    icon: Icons.phone_rounded,
                    title: 'Позвонить',
                    subtitle: _phoneNumber,
                    onTap: () async {
                      _request();
                      final url = Uri.parse('tel:$_phoneNumber');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                  SizedBox(height: 1.5.h),
                  _animatedContactCard(
                    order: 1,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Написать в WhatsApp',
                    subtitle: _phoneNumber,
                    onTap: _openWhatsApp,
                    badgeColor: Colors.green,
                  ),
                  SizedBox(height: 1.5.h),
                  _animatedContactCard(
                    order: 2,
                    icon: Icons.send_rounded,
                    title: 'Написать в Telegram',
                    subtitle: _telegramHandle,
                    onTap: _openTelegram,
                    badgeColor: const Color(0xFF0088CC),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3.h),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 5.w),
                child: Text(
                  'Мы свяжемся с вами в ближайшее время и поможем разместить объявление.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFFB4B4BA),
                    height: 1.5,
                  ),
                ),
              ),
            ),

            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  // ── Animated contact card ─────────────────────────────────────
  // Reuses the pre-created controller/animation for this `order` instead of
  // creating a new AnimationController on every build (that was the source
  // of the ticker leak — controllers were created here but never stored or
  // disposed).
  Widget _animatedContactCard({
    required int order,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color badgeColor = _accentBlue,
  }) {
    final animation = _contactCardAnimations[order];

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, (1 - animation.value) * 2.h),
          child: child,
        ),
      ),
      child: _HoverContactCard(
        onTap: onTap,
        badgeColor: badgeColor,
        icon: icon,
        title: title,
        subtitle: subtitle,
      ),
    );
  }
}

// ── Hover Contact Card ────────────────────────────────────────
class _HoverContactCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color badgeColor;

  const _HoverContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.badgeColor,
  });

  @override
  State<_HoverContactCard> createState() => _HoverContactCardState();
}

class _HoverContactCardState extends State<_HoverContactCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverController;
  late final Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _hoverAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 1.02).animate(_hoverAnimation),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(4.w),
              border: Border.all(
                color: widget.badgeColor.withOpacity(0.1),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.badgeColor.withOpacity(
                      0.08 + (_hoverAnimation.value * 0.12)),
                  blurRadius: 12 + (_hoverAnimation.value * 8),
                  offset: Offset(0, 4 + (_hoverAnimation.value * 4)),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 11.w,
                  height: 11.w,
                  decoration: BoxDecoration(
                    color: widget.badgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  child: Icon(widget.icon,
                      color: widget.badgeColor, size: 2.8.h),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111111),
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 0.3.h),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: widget.badgeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: const Color(0xFFCCCCCC), size: 2.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}