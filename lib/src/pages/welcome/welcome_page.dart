import 'package:flutter/material.dart';
import 'package:new_app/src/authentifications/sign_in/sign_in.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key, required void Function() onDone}) : super(key: key);

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveSizer(
      builder: (context, orientation, screenType) => Scaffold(
        backgroundColor: const Color(0xFFEAE7F3),
        body: Stack(
          children: [
            // ── Decorative circles ──────────────────────────────────
            Positioned(
              top: -6.h,
              right: -8.w,
              child: Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD6CEEE).withOpacity(0.55),
                ),
              ),
            ),
            Positioned(
              top: 6.h,
              left: -10.w,
              child: Container(
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC2BAE0).withOpacity(0.35),
                ),
              ),
            ),

            Column(
              children: [
                // ── Hero section ──────────────────────────────────
                Expanded(
                  flex: 42,
                  child: Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Column(
                      children: [
                        // Logo / brand pill
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(8.w),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_car_rounded,
                                  color: Colors.white, size: 13.sp),
                              SizedBox(width: 2.w),
                              Text(
                                'Gravitas Auto',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1.w,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 2.h),

                        // Car image with shadow plate
                        Expanded(
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              // Oval shadow / ground reflection
                              Positioned(
                                bottom: 1.5.h,
                                child: Container(
                                  width: 55.w,
                                  height: 2.5.h,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(13.w),
                                    color: const Color(0xFF7B72B0)
                                        .withOpacity(0.18),
                                  ),
                                ),
                              ),
                              // Car image
                              Padding(
                                padding: EdgeInsets.only(bottom: 2.h),
                                child: Transform.scale(
                                  scale: 1.15,
                                  child: Image.asset(
                                    'assets/images/car.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── White card ──────────────────────────────────────
                Expanded(
                  flex: 58,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(9.5.w)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(6.w, 3.5.h, 6.w, 4.h),
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Drag handle
                              Center(
                                child: Container(
                                  width: 10.w,
                                  height: 0.5.h,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E0E0),
                                    borderRadius: BorderRadius.circular(3.w),
                                  ),
                                ),
                              ),

                              SizedBox(height: 2.h),

                              // Title
                              Text(
                                'Добро пожаловать\nв Gravitas Auto!',
                                style: TextStyle(
                                  fontSize: 21.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1C1C1E),
                                  height: 1.25,
                                  letterSpacing: -0.15.w,
                                ),
                              ),

                              SizedBox(height: 0.8.h),

                              // Subtitle
                              Text(
                                'Покупайте и продавайте автомобили с уверенностью.\nТысячи довольных клиентов.',
                                style: TextStyle(
                                  fontSize: 12.5.sp,
                                  color: const Color(0xFF8A8A8E),
                                  height: 1.55,
                                ),
                              ),

                              SizedBox(height: 2.h),

                              // Feature rows
                              _FeatureItem(
                                icon: Icons.search_rounded,
                                text: 'Быстрый поиск по вашим критериям',
                                accent: const Color(0xFF6C63B6),
                              ),
                              SizedBox(height: 1.h),
                              _FeatureItem(
                                icon: Icons.verified_user_rounded,
                                text: 'Проверенные продавцы и покупатели',
                                accent: const Color(0xFF4CAF7D),
                              ),
                              SizedBox(height: 1.h),
                              _FeatureItem(
                                icon: Icons.local_offer_rounded,
                                text: 'Выгодные предложения каждый день',
                                accent: const Color(0xFFE8954A),
                              ),

                              SizedBox(height: 2.5.h),

                              // CTA button
                              SizedBox(
                                width: double.infinity,
                                height: 6.5.h,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const SignIn(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1C1C1E),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5.3.w),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Приступить',
                                        style: TextStyle(
                                          fontSize: 14.5.sp,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.1.w,
                                        ),
                                      ),
                                      SizedBox(width: 2.5.w),
                                      Container(
                                        padding: EdgeInsets.all(1.w),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 13.sp,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(height: 1.2.h),

                              // Footer hint
                              Center(
                                child: Text(
                                  'Регистрируясь, вы соглашаетесь с условиями',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: const Color(0xFFB0B0B5),
                                  ),
                                ),
                              ),
                            ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feature row ──────────────────────────────────────────────────────────────
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;

  const _FeatureItem({
    required this.icon,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.6.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(4.3.w),
        border: Border.all(
          color: const Color(0xFFEEEEF0),
          width: 0.27.w,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 13.w,
            height: 9.w,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(3.7.w),
            ),
            child: Icon(icon, color: accent, size: 18.sp),
          ),
          SizedBox(width: 3.5.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 13.sp,
            color: const Color(0xFFCCCCCC),
          ),
        ],
      ),
    );
  }
}