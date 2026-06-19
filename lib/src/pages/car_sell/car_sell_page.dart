import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class CarSellPage extends StatefulWidget {
  const CarSellPage({Key? key}) : super(key: key);

  @override
  State<CarSellPage> createState() => _CarSellPageState();
}

class _CarSellPageState extends State<CarSellPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ── Text controllers ──────────────────────────────────────────
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();
  final _kmController = TextEditingController();
  final _priceController = TextEditingController();
  final _engineController = TextEditingController();
  final _colorController = TextEditingController();
  final _locationController = TextEditingController();

  // ── Dropdown selections ───────────────────────────────────────
  String? _transmission;
  String? _fuelType;
  String? _bodyType;

  static const _transmissions = ['Механика', 'Автомат', 'Робот', 'Вариатор'];
  static const _fuelTypes = ['Бензин', 'Дизель', 'Газ', 'Электро', 'Гибрид'];
  static const _bodyTypes = [
    'Седан', 'Хэтчбек', 'Внедорожник', 'Универсал', 'Купе', 'Минивэн'
  ];

  // Monochrome accent (near-black)
  static const _accent = Color(0xFF111111);

  // ── Animations ────────────────────────────────────────────────
  late final AnimationController _overlayController; // blur + paywall card
  late final AnimationController _formController;     // staggered form entrance
  late final AnimationController _pulseController;    // gentle icon pulse
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Form animates in immediately; paywall pops in a beat later.
    _formController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _overlayController.forward();
      });
    });
  }

  @override
  void dispose() {
    _overlayController.dispose();
    _formController.dispose();
    _pulseController.dispose();
    _nameController.dispose();
    _yearController.dispose();
    _kmController.dispose();
    _priceController.dispose();
    _engineController.dispose();
    _colorController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // "Может быть позже" → return to AddPage (the screen this was opened from).
  void _onLaterTap() {
    Navigator.pop(context);

    // If you DON'T open this page from AddPage and want to force-open it,
    // add `import 'add_page.dart';` at the top and use this instead:
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(builder: (_) => const AddPage()),
    // );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    final car = Car(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      year: _yearController.text.trim(),
      km: _kmController.text.trim(),
      price: _priceController.text.trim(),
      transmission: _transmission!,
      fuelType: _fuelType!,
      engineCapacity: _engineController.text.trim(),
      bodyType: _bodyType!,
      color: _colorController.text.trim(),
      location: _locationController.text.trim(),
    );

    // TODO: send `car` to your backend / provider here.
    Navigator.pop(context, car);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F4),
      body: Stack(
        children: [
          SafeArea(child: _buildForm()),
          _buildPaywallOverlay(),
        ],
      ),
    );
  }

  // ── Form ──────────────────────────────────────────────────────
  Widget _buildForm() {
    int order = 0;
    Widget anim(Widget child) => _animatedEntry(order: order++, child: child);

    return Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(5.w, 1.h, 5.w, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 1.h),
                  child:
                      Icon(Icons.arrow_back, color: Colors.black, size: 3.2.h),
                ),
              ),
              SizedBox(height: 1.5.h),
              anim(Text(
                'Продажа авто',
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              )),
              SizedBox(height: 0.6.h),
              anim(Text(
                'Укажите характеристики вашего автомобиля.',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF9A9AA0),
                ),
              )),
            ],
          ),
        ),

        // Scrollable form
        Expanded(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(5.w, 3.h, 5.w, 2.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  anim(_section('Основное')),
                  anim(_textField(
                    label: 'Марка и модель',
                    controller: _nameController,
                    hint: 'Toyota Camry',
                    icon: Icons.directions_car_outlined,
                  )),
                  anim(_textField(
                    label: 'Цена, \$',
                    controller: _priceController,
                    hint: '15 000',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  )),
                  anim(_section('Характеристики')),
                  anim(Row(
                    children: [
                      Expanded(
                        child: _textField(
                          label: 'Год',
                          controller: _yearController,
                          hint: '2018',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: _textField(
                          label: 'Пробег, км',
                          controller: _kmController,
                          hint: '85 000',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  )),
                  anim(_dropdownField(
                    label: 'Коробка передач',
                    value: _transmission,
                    items: _transmissions,
                    icon: Icons.settings_outlined,
                    onChanged: (v) => setState(() => _transmission = v),
                  )),
                  anim(_dropdownField(
                    label: 'Тип топлива',
                    value: _fuelType,
                    items: _fuelTypes,
                    icon: Icons.local_gas_station_outlined,
                    onChanged: (v) => setState(() => _fuelType = v),
                  )),
                  anim(_dropdownField(
                    label: 'Тип кузова',
                    value: _bodyType,
                    items: _bodyTypes,
                    icon: Icons.airport_shuttle_outlined,
                    onChanged: (v) => setState(() => _bodyType = v),
                  )),
                  anim(Row(
                    children: [
                      Expanded(
                        child: _textField(
                          label: 'Объём, л',
                          controller: _engineController,
                          hint: '2.0',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: _textField(
                          label: 'Цвет',
                          controller: _colorController,
                          hint: 'Чёрный',
                        ),
                      ),
                    ],
                  )),
                  anim(_section('Расположение')),
                  anim(_textField(
                    label: 'Город',
                    controller: _locationController,
                    hint: 'Бишкек',
                    icon: Icons.location_on_outlined,
                  )),
                  SizedBox(height: 2.h),
                  anim(_submitButton()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Paywall overlay (blur + centered card) ────────────────────
  Widget _buildPaywallOverlay() {
    return AnimatedBuilder(
      animation: _overlayController,
      builder: (context, _) {
        final t = _overlayController.value;
        if (t == 0) return const SizedBox.shrink();

        final blur = 16.0 * t;
        final back = Curves.easeOutBack.transform(t); // overshoot for a pop

        return Positioned.fill(
          child: IgnorePointer(
            ignoring: t < 0.05,
            child: Stack(
              children: [
                // Blurred, dimmed backdrop (absorbs taps so the form stays locked)
                GestureDetector(
                  onTap: () {},
                  behavior: HitTestBehavior.opaque,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: Container(
                      color: Colors.black.withOpacity(0.28 * t),
                    ),
                  ),
                ),
                // Centered card
                Center(
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, (1 - back) * 5.h),
                      child: Transform.scale(
                        scale: 0.86 + 0.14 * back,
                        child: _paywallCard(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _paywallCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w),
      padding: EdgeInsets.fromLTRB(6.w, 4.h, 6.w, 3.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing icon badge (black)
          ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A2A2A), Color(0xFF000000)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(Icons.workspace_premium,
                  color: Colors.white, size: 5.h),
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'Публикация объявления',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 1.2.h),
          Text(
            'Чтобы разместить ваш автомобиль на платформе, нужна разовая оплата.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFF9A9AA0),
              height: 1.4,
            ),
          ),
          SizedBox(height: 3.h),
          // Price (black)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '5',
                style: TextStyle(
                  fontSize: 34.sp,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                  letterSpacing: -1,
                ),
              ),
              Text(
                ' \$',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                ),
              ),
            ],
          ),
          SizedBox(height: 0.4.h),
          Text(
            'Единоразовый платёж',
            style: TextStyle(
              fontSize: 11.5.sp,
              color: const Color(0xFFB4B4BA),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 3.5.h),
          // Pay button — placeholder, does nothing for now (black)
          _PressableScale(
            onTap: () {
              // TODO: integrate payment here. Disabled for now.
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 2.2.h),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(4.w),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'Оплатить 5 \$',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          SizedBox(height: 1.h),
          // "Может быть позже" → goes back to AddPage
          GestureDetector(
            onTap: _onLaterTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 1.h),
              child: Text(
                'Может быть позже',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF9A9AA0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable pieces ───────────────────────────────────────────

  Widget _animatedEntry({required int order, required Widget child}) {
    final start = (order * 0.06).clamp(0.0, 0.7);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: _formController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, c) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curved.value) * 2.5.h),
          child: c,
        ),
      ),
      child: child,
    );
  }

  Widget _section(String title) => Padding(
        padding: EdgeInsets.only(bottom: 1.6.h, top: 0.5.h),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: -0.3,
          ),
        ),
      );

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(left: 1.w, bottom: 0.9.h),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6A6A70),
          ),
        ),
      );

  InputDecoration _decoration({String? hint, IconData? icon}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(4.w),
          borderSide: BorderSide(color: c, width: 1.4),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13.sp,
        color: const Color(0xFFB4B4BA),
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: icon != null
          ? Icon(icon, color: const Color(0xFF8A8A90), size: 2.4.h)
          : null,
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      enabledBorder: border(const Color(0xFFEAEAEE)),
      focusedBorder: border(_accent),
      errorBorder: border(const Color(0xFF555555)),
      focusedErrorBorder: border(const Color(0xFF555555)),
      errorStyle: TextStyle(fontSize: 10.sp, color: const Color(0xFF555555)),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          cursorColor: _accent,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Заполните поле' : null,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
          decoration: _decoration(hint: hint, icon: icon),
        ),
        SizedBox(height: 2.h),
      ],
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF8A8A90)),
          borderRadius: BorderRadius.circular(4.w),
          validator: (v) => v == null ? 'Выберите значение' : null,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
          hint: Text(
            'Выберите',
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFFB4B4BA),
              fontWeight: FontWeight.w400,
            ),
          ),
          decoration: _decoration(icon: icon),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
        SizedBox(height: 2.h),
      ],
    );
  }

  Widget _submitButton() {
    return _PressableScale(
      onTap: _submit,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 2.2.h),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(4.w),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'Опубликовать объявление',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

// ── Press-to-scale wrapper (reusable) ─────────────────────────────
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;
  const _PressableScale({
    required this.child,
    required this.onTap,
    this.scale = 0.97,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
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
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}