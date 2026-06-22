import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_app/src/pages/autoslon/permission/publish_permission.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

/// Dedicated publish form for the car-sell flow. [CarSellPage] only handles
/// the access-request flow now; once permission is granted it pushes this
/// page, which owns the actual form, the publish confirmation, and consuming
/// the one-time permission. On success it pops with the new [Car].
class CarPublishPage extends StatefulWidget {
  const CarPublishPage({Key? key}) : super(key: key);

  @override
  State<CarPublishPage> createState() => _CarPublishPageState();
}

class _CarPublishPageState extends State<CarPublishPage>
    with SingleTickerProviderStateMixin {
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

  // Accent color — publish actions are black, matching the autoslon flow.
  static const _accent = Color(0xFF111111);

  // ── Entrance animation (same staggered approach as autoslon) ──
  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _nameController.dispose();
    _yearController.dispose();
    _kmController.dispose();
    _priceController.dispose();
    _engineController.dispose();
    _colorController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // Staggered entrance animation helper, identical pattern to AutoslonPublishPage.
  Widget _anim(int order, Widget child) {
    final start = (order * 0.08).clamp(0.0, 0.7);
    final curved = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (_, c) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curved.value) * 2.5.h),
          child: c,
        ),
      ),
      child: child,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    // Capture the notifier before any await (avoids using context across gaps).
    final notifier = context.read<CarSellPermissionNotifier>();

    // The publish button does not publish immediately: confirm first.
    final confirmed = await showPublishConfirmDialog(context);
    if (!confirmed || !mounted) return;

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

    // Consume the one-time permission, then return the new car. After this the
    // user must request permission again for the next listing.
    await notifier.consume();
    if (!mounted) return;

    Navigator.pop(context, car);
  }

  @override
  Widget build(BuildContext context) {
    int order = 0;
    Widget a(Widget c) => _anim(order++, c);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header — back arrow sits inline to the left of the title,
            // right at the very top, like a normal app bar.
            Padding(
              padding: EdgeInsets.fromLTRB(5.w, 0.5.h, 5.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.only(right: 3.w),
                          child: Icon(Icons.arrow_back,
                              color: _accent, size: 3.2.h),
                        ),
                      ),
                      Expanded(
                        child: a(Text(
                          'Продажа авто',
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w800,
                            color: _accent,
                            letterSpacing: -0.5,
                          ),
                        )),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  a(Text(
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
                      a(_section('Основное')),
                      a(_textField(
                        label: 'Марка и модель',
                        controller: _nameController,
                        hint: 'Toyota Camry',
                        icon: Icons.directions_car_outlined,
                      )),
                      a(_textField(
                        label: 'Цена, \$',
                        controller: _priceController,
                        hint: '15 000',
                        icon: Icons.attach_money,
                        keyboardType: TextInputType.number,
                      )),
                      a(_section('Характеристики')),
                      a(Row(
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
                      a(_dropdownField(
                        label: 'Коробка передач',
                        value: _transmission,
                        items: _transmissions,
                        icon: Icons.settings_outlined,
                        onChanged: (v) => setState(() => _transmission = v),
                      )),
                      a(_dropdownField(
                        label: 'Тип топлива',
                        value: _fuelType,
                        items: _fuelTypes,
                        icon: Icons.local_gas_station_outlined,
                        onChanged: (v) => setState(() => _fuelType = v),
                      )),
                      a(_dropdownField(
                        label: 'Тип кузова',
                        value: _bodyType,
                        items: _bodyTypes,
                        icon: Icons.airport_shuttle_outlined,
                        onChanged: (v) => setState(() => _bodyType = v),
                      )),
                      a(Row(
                        children: [
                          Expanded(
                            child: _textField(
                              label: 'Объём, л',
                              controller: _engineController,
                              hint: '2.0',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                      a(_section('Расположение')),
                      a(_textField(
                        label: 'Город',
                        controller: _locationController,
                        hint: 'Бишкек',
                        icon: Icons.location_on_outlined,
                      )),
                      SizedBox(height: 2.h),
                      a(_submitButton()),
                      SizedBox(height: 2.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────

  Widget _section(String title) => Padding(
        padding: EdgeInsets.only(bottom: 1.6.h, top: 0.5.h),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: _accent,
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
            color: _accent,
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
            color: _accent,
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
    return _AnimatedPressableButton(
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

// ── Animated Pressable Button ─────────────────────────────────
class _AnimatedPressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  const _AnimatedPressableButton({
    required this.child,
    required this.onTap,
    this.scale = 0.97,
  });

  @override
  State<_AnimatedPressableButton> createState() =>
      _AnimatedPressableButtonState();
}

class _AnimatedPressableButtonState extends State<_AnimatedPressableButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _pressAnimation = Tween<double>(begin: 1, end: widget.scale).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _pressAnimation,
        child: widget.child,
      ),
    );
  }
}