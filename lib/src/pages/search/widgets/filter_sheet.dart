import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_app/src/app/app_theme.dart';
import 'package:new_app/src/app/ui_kit.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import '../search_filters.dart';

/// Открывает лист фильтров. Возвращает новые фильтры или null, если
/// пользователь просто закрыл лист.
Future<SearchFilters?> showFilterSheet(
  BuildContext context, {
  required SearchFilters initial,
  required List<Car> Function(SearchFilters) preview,
}) {
  return showModalBottomSheet<SearchFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FilterSheet(initial: initial, preview: preview),
  );
}

class _FilterSheet extends StatefulWidget {
  final SearchFilters initial;
  final List<Car> Function(SearchFilters) preview;

  const _FilterSheet({required this.initial, required this.preview});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SearchFilters _f = widget.initial;

  late final _minPrice = TextEditingController(text: _fmt(_f.minPrice));
  late final _maxPrice = TextEditingController(text: _fmt(_f.maxPrice));
  late final _yearFrom = TextEditingController(
    text: _f.yearFrom?.toString() ?? '',
  );
  late final _yearTo = TextEditingController(text: _f.yearTo?.toString() ?? '');

  static String _fmt(int? v) => v == null ? '' : v.toString();

  @override
  void dispose() {
    _minPrice.dispose();
    _maxPrice.dispose();
    _yearFrom.dispose();
    _yearTo.dispose();
    super.dispose();
  }

  void _syncNumbers() {
    setState(() {
      _f = _f.copyWith(
        minPrice: () => parseAmount(_minPrice.text),
        maxPrice: () => parseAmount(_maxPrice.text),
        yearFrom: () => parseAmount(_yearFrom.text),
        yearTo: () => parseAmount(_yearTo.text),
      );
    });
  }

  Set<String> _toggle(Set<String> set, String v) {
    final next = {...set};
    if (!next.remove(v)) next.add(v);
    return next;
  }

  void _reset() {
    HapticFeedback.lightImpact();
    _minPrice.clear();
    _maxPrice.clear();
    _yearFrom.clear();
    _yearTo.clear();
    setState(() => _f = _f.cleared());
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.preview(_f).length;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Фильтры',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _f.activeCount > 0 ? _reset : null,
                    child: const Text(
                      'Сбросить',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                children: [
                  _title('Цена, \$'),
                  _rangeRow(_minPrice, _maxPrice, 'от', 'до'),
                  _title('Год выпуска'),
                  _rangeRow(_yearFrom, _yearTo, 'с', 'по', maxLength: 4),
                  _title('Кузов'),
                  _chips(
                    SearchOptions.bodyTypes,
                    _f.bodyTypes,
                    (v) => _f.copyWith(bodyTypes: _toggle(_f.bodyTypes, v)),
                  ),
                  _title('Топливо'),
                  _chips(
                    SearchOptions.fuelTypes,
                    _f.fuelTypes,
                    (v) => _f.copyWith(fuelTypes: _toggle(_f.fuelTypes, v)),
                  ),
                  _title('Коробка'),
                  _chips(
                    SearchOptions.transmissions,
                    _f.transmissions,
                    (v) => _f.copyWith(
                      transmissions: _toggle(_f.transmissions, v),
                    ),
                  ),
                  _title('Привод'),
                  _chips(
                    SearchOptions.driveTypes,
                    _f.driveTypes,
                    (v) => _f.copyWith(driveTypes: _toggle(_f.driveTypes, v)),
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    child: SwitchListTile.adaptive(
                      value: _f.onlyAutosalon,
                      activeTrackColor: AppColors.primary,
                      onChanged: (v) =>
                          setState(() => _f = _f.copyWith(onlyAutosalon: v)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      secondary: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Только автосалоны',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              child: GradientButton(
                label: count == 0
                    ? 'Ничего не найдено'
                    : 'Показать ${formatThousands(count)} авто',
                onPressed: () => Navigator.pop(context, _f),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    ),
  );

  Widget _rangeRow(
    TextEditingController from,
    TextEditingController to,
    String fromHint,
    String toHint, {
    int? maxLength,
  }) {
    Widget field(TextEditingController c, String hint) => Expanded(
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        ],
        onChanged: (_) => _syncNumbers(),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          fillColor: AppColors.surfaceAlt,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
    return Row(
      children: [
        field(from, fromHint),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('—', style: TextStyle(color: AppColors.muted)),
        ),
        field(to, toHint),
      ],
    );
  }

  Widget _chips(
    List<String> options,
    Set<String> selected,
    SearchFilters Function(String) onToggle,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          SelectChip(
            label: o,
            selected: selected.contains(o),
            onTap: () => setState(() => _f = onToggle(o)),
          ),
      ],
    );
  }
}

/// Чип-переключатель с плавной сменой цвета.
class SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.hairline,
          ),
          boxShadow: selected ? AppColors.softShadow(0.15) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
