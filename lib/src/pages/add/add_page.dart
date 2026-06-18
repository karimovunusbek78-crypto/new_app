import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class AddPage extends StatefulWidget {
  const AddPage({Key? key}) : super(key: key);

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> with TickerProviderStateMixin {
  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  void _onServiceTap() {
    // TODO: navigate to "Автосервис" creation flow
    // Navigator.push(context, MaterialPageRoute(builder: (_) => const AddServicePage()));
  }

  void _onCarSaleTap() {
    // TODO: navigate to "Продажа авто" creation flow
    // Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCarPage()));
  }

  /// Builds a fade + slide-up entrance for a child, staggered by [order].
  Widget _animatedEntry({required int order, required Widget child}) {
    final start = (order * 0.12).clamp(0.0, 1.0);
    final end = (start + 0.6).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, c) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * 3.h),
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F4),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(5.w, 1.h, 5.w, 4.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back button ──────────────────────────────────────────────
              SizedBox(height: 1.h),
              _BackButton(onTap: () => Navigator.maybePop(context)),

              SizedBox(height: 3.h),

              // ── Title ────────────────────────────────────────────────────
              _animatedEntry(
                order: 0,
                child: Text(
                  'Выберите тип\nобъявления',
                  style: TextStyle(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              SizedBox(height: 1.5.h),

              // ── Subtitle ─────────────────────────────────────────────────
              _animatedEntry(
                order: 1,
                child: Text(
                  'Пожалуйста, выберите, что вы хотите\nдобавить на платформу.',
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    color: const Color(0xFF9A9AA0),
                    height: 1.35,
                  ),
                ),
              ),

              SizedBox(height: 4.5.h),

              // ── Card 1: Автосервис ───────────────────────────────────────
              _animatedEntry(
                order: 2,
                child: _TypeCard(
                  gradient: const [Color(0xFFEDE7FB), Color(0xFFD7C7F5)],
                  icon: Icons.garage_outlined,
                  iconColor: const Color(0xFF6C4FD6),
                  accent: const Color(0xFF6C4FD6),
                  title: 'Автосервис',
                  description:
                      'Разместите информацию о вашем автосервисе, услугах и получите больше клиентов.',
                  onTap: _onServiceTap,
                ),
              ),

              SizedBox(height: 2.4.h),

              // ── Card 2: Просто продажа авто ──────────────────────────────
              _animatedEntry(
                order: 3,
                child: _TypeCard(
                  gradient: const [Color(0xFFE3ECFB), Color(0xFFC8DDF8)],
                  icon: Icons.directions_car_filled_outlined,
                  iconColor: const Color(0xFF3C6FE0),
                  accent: const Color(0xFF3C6FE0),
                  title: 'Просто продажа авто',
                  description:
                      'Разместите объявление о продаже вашего автомобиля и найдите покупателя.',
                  onTap: _onCarSaleTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Back button (with press feedback) ──────────────────────────────────────────

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 10.w,
          height: 10.w,
          alignment: Alignment.centerLeft,
          child: Icon(
            Icons.arrow_back,
            color: Colors.black,
            size: 3.2.h,
          ),
        ),
      ),
    );
  }
}

// ── Type card (with press feedback) ─────────────────────────────────────────────

class _TypeCard extends StatefulWidget {
  final List<Color> gradient;
  final IconData icon;
  final Color iconColor;
  final Color accent;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _TypeCard({
    required this.gradient,
    required this.icon,
    required this.iconColor,
    required this.accent,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: 4.5.w, vertical: 3.2.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6.w),
            border: Border.all(color: const Color(0xFFEFEFF1), width: 1),
            boxShadow: [
              // Soft neutral lift
              BoxShadow(
                color: Colors.black.withOpacity(_down ? 0.03 : 0.05),
                blurRadius: _down ? 8 : 20,
                offset: Offset(0, _down ? 3 : 9),
              ),
              // Subtle accent-tinted glow matching the icon
              BoxShadow(
                color: widget.accent.withOpacity(_down ? 0.05 : 0.12),
                blurRadius: _down ? 10 : 26,
                offset: Offset(0, _down ? 4 : 12),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon tile — subtle gradient for depth
              Container(
                width: 17.w,
                height: 17.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradient,
                  ),
                  borderRadius: BorderRadius.circular(4.5.w),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 4.6.h),
              ),

              SizedBox(width: 4.5.w),

              // Text block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 16.5.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 0.8.h),
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        color: const Color(0xFF9A9AA0),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 2.5.w),

              // Chevron in a soft circle
              Container(
                width: 8.5.w,
                height: 8.5.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: const Color(0xFF8A8A90),
                  size: 2.9.h,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}