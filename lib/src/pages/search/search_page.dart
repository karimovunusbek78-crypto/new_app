import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_app/src/app/app_theme.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/video/controller/main_tab_controller.dart';
import 'search_filters.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/suggestions_view_widget.dart';
import 'widgets/search_results_widget.dart';
import 'widgets/category_grid_widget.dart';
import 'widgets/brand_list_widget.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _recentKey = 'search.recent';

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  SearchFilters _filters = const SearchFilters();
  SortMode _sort = SortMode.newest;
  List<String> _recentSearches = [];
  NavTabController? _nav;

  static const List<CarCategory> _categories = [
    CarCategory('Седан', Icons.directions_car_rounded, Color(0xFF5B4CF0)),
    CarCategory('Внедорожник', Icons.terrain_rounded, Color(0xFF16A34A)),
    CarCategory('Хэтчбек', Icons.commute_rounded, Color(0xFFF59E0B)),
    CarCategory('Купе', Icons.sports_score_rounded, Color(0xFFEF4444)),
    CarCategory('Универсал', Icons.airport_shuttle_rounded, Color(0xFF0EA5E9)),
    CarCategory('Минивэн', Icons.family_restroom_rounded, Color(0xFFA855F7)),
    CarCategory(
      'Электро',
      Icons.electric_bolt_rounded,
      Color(0xFF14B8A6),
      isFuel: true,
    ),
    CarCategory('Гибрид', Icons.eco_rounded, Color(0xFF65A30D), isFuel: true),
  ];

  static const List<CarBrand> _brands = [
    CarBrand('BMW', 'assets/images/bmw.png'),
    CarBrand('Audi', 'assets/images/audi.png'),
    CarBrand('Mercedes', 'assets/images/mersedes.png'),
    CarBrand('Toyota', 'assets/images/toyota.png'),
    CarBrand('Lexus', 'assets/images/lexus.png'),
    CarBrand('Kia', 'assets/images/kia.png'),
    CarBrand('Hyundai', 'assets/images/hyundai.png'),
    CarBrand('Tesla', 'assets/images/tesla.png'),
  ];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.read<NavTabController>();
    if (!identical(nav, _nav)) {
      _nav?.removeListener(_onNavChanged);
      _nav = nav..addListener(_onNavChanged);
    }
  }

  /// Фокус ставим только когда таб "Поиск" реально открыли (например,
  /// тапом по строке поиска на Главной), а при уходе с таба — снимаем,
  /// чтобы клавиатура не висела поверх других экранов.
  void _onNavChanged() {
    final nav = _nav!;
    if (nav.currentIndex == 1 && nav.pendingSearchFocus) {
      nav.pendingSearchFocus = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (nav.currentIndex != 1 && _focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _nav?.removeListener(_onNavChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_recentKey) ?? const [];
      if (mounted) setState(() => _recentSearches = [...saved]);
    } catch (_) {}
  }

  Future<void> _saveRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentKey, _recentSearches);
    } catch (_) {}
  }

  bool get _hasActiveSearch =>
      _controller.text.trim().isNotEmpty || !_filters.isEmpty;

  List<Car> _results(List<Car> source, [SearchFilters? filters]) => applySearch(
    source,
    query: _controller.text,
    filters: filters ?? _filters,
    sort: _sort,
  );

  void _registerSearch(String term) {
    term = term.trim();
    if (term.isEmpty) return;
    setState(() {
      _recentSearches.remove(term);
      _recentSearches.insert(0, term);
      if (_recentSearches.length > 8) _recentSearches.removeLast();
    });
    _saveRecent();
  }

  void _selectTerm(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: term.length),
    );
    _focusNode.unfocus();
    _registerSearch(term);
  }

  void _selectCategory(CarCategory cat) {
    HapticFeedback.selectionClick();
    _focusNode.unfocus();
    setState(() {
      _filters = cat.isFuel
          ? _filters.copyWith(fuelTypes: {cat.label})
          : _filters.copyWith(bodyTypes: {cat.label});
    });
  }

  Future<void> _openFilters(List<Car> source) async {
    _focusNode.unfocus();
    final result = await showFilterSheet(
      context,
      initial: _filters,
      preview: (f) => _results(source, f),
    );
    if (result != null && mounted) setState(() => _filters = result);
  }

  void _resetAll() {
    HapticFeedback.lightImpact();
    _controller.clear();
    setState(() => _filters = const SearchFilters());
  }

  @override
  Widget build(BuildContext context) {
    // CarsProvider.cars — полный список опубликованных объявлений
    // (тот же источник, что использует Главная).
    final provider = context.watch<CarsProvider>();
    final allPublishedCars = provider.cars;
    final active = _hasActiveSearch;
    final results = active ? _results(allPublishedCars) : const <Car>[];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Text(
                      'Поиск',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      provider.isLoading
                          ? ''
                          : active
                          ? 'Найдено: ${formatThousands(results.length)}'
                          : '${formatThousands(allPublishedCars.length)} объявлений',
                      key: ValueKey('$active${results.length}'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SearchBarWidget(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: () => setState(() {}),
              onSubmitted: _registerSearch,
              onFilterTap: () => _openFilters(allPublishedCars),
              activeFilters: _filters.activeCount,
            ),
            _QuickChipsRow(
              sort: _sort,
              filters: _filters,
              showReset: active,
              onSort: (s) => setState(() => _sort = s),
              onVideo: (v) =>
                  setState(() => _filters = _filters.copyWith(onlyVideo: v)),
              onReset: _resetAll,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.03),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: active
                    ? SearchResultsWidget(
                        key: ValueKey(
                          'results-${_sort.name}-${_filters.onlyVideo}',
                        ),
                        results: results,
                        videoGrid: _filters.onlyVideo,
                      )
                    : SuggestionsViewWidget(
                        key: const ValueKey('suggestions'),
                        recentSearches: _recentSearches,
                        categories: _categories,
                        brands: _brands,
                        onSelect: _selectTerm,
                        onCategory: _selectCategory,
                        onRemoveRecent: (term) {
                          setState(() => _recentSearches.remove(term));
                          _saveRecent();
                        },
                        onClearRecent: () {
                          setState(() => _recentSearches.clear());
                          _saveRecent();
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChipsRow extends StatelessWidget {
  final SortMode sort;
  final SearchFilters filters;
  final bool showReset;
  final ValueChanged<SortMode> onSort;
  final ValueChanged<bool> onVideo;
  final VoidCallback onReset;

  const _QuickChipsRow({
    required this.sort,
    required this.filters,
    required this.showReset,
    required this.onSort,
    required this.onVideo,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          Center(
            child: SelectChip(
              label: 'Видео',
              icon: Icons.play_circle_fill_rounded,
              selected: filters.onlyVideo,
              onTap: () => onVideo(!filters.onlyVideo),
            ),
          ),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            color: AppColors.hairline,
          ),
          for (final s in SortMode.values) ...[
            Center(
              child: SelectChip(
                label: s.label,
                selected: sort == s,
                onTap: () => onSort(s),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (showReset)
            Center(
              child: SelectChip(
                label: 'Сбросить всё',
                icon: Icons.restart_alt_rounded,
                selected: false,
                onTap: onReset,
              ),
            ),
        ],
      ),
    );
  }
}