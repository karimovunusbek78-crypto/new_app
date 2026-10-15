import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/price_filter_widget.dart';
import 'widgets/suggestions_view_widget.dart';
import 'widgets/search_results_widget.dart';
import 'widgets/category_grid_widget.dart';
import 'widgets/brand_list_widget.dart';

enum ResultFilter { all, video, listing }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  ResultFilter _filter = ResultFilter.all;

  final List<String> _recentSearches = [
    'BMW M4',
    'Audi RS7 2024',
    'Tesla Model 3',
  ];

  final List<CarCategory> _categories = const [
    CarCategory('Седан', Icons.directions_car),
    CarCategory('Внедорожник', Icons.directions_car_filled),
    CarCategory('Хэтчбэк', Icons.commute),
    CarCategory('Купе', Icons.time_to_leave),
    CarCategory('Кроссовер', Icons.terrain),
    CarCategory('Минивэн', Icons.airport_shuttle),
    CarCategory('Пикап', Icons.local_shipping),
    CarCategory('Электро', Icons.electric_bolt),
  ];

  final List<CarBrand> _brands = const [
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  double _parsePrice(String price) {
    final digitsOnly = price.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return 0;
    return double.parse(digitsOnly);
  }

  bool _hasActiveFilter() {
    return _controller.text.trim().isNotEmpty ||
        _minPriceController.text.trim().isNotEmpty ||
        _maxPriceController.text.trim().isNotEmpty ||
        _filter != ResultFilter.all;
  }

  List<Car> _getFilteredCars(List<Car> source) {
    final q = _controller.text.trim().toLowerCase();
    final minPrice = double.tryParse(_minPriceController.text.trim());
    final maxPrice = double.tryParse(_maxPriceController.text.trim());

    return source.where((car) {
      final hasVideo = car.videoPath != null && car.videoPath!.isNotEmpty;
      final matchesFilter = switch (_filter) {
        ResultFilter.all => true,
        ResultFilter.video => hasVideo,
        ResultFilter.listing => !hasVideo,
      };
      if (!matchesFilter) return false;

      final matchesQuery = q.isEmpty ||
          car.name.toLowerCase().contains(q) ||
          car.year.toLowerCase().contains(q) ||
          car.bodyType.toLowerCase().contains(q) ||
          car.color.toLowerCase().contains(q) ||
          car.location.toLowerCase().contains(q) ||
          car.fuelType.toLowerCase().contains(q) ||
          car.engineCapacity.toLowerCase().contains(q) ||
          car.transmission.toLowerCase().contains(q);

      final carPrice = _parsePrice(car.price);
      final matchesMin = minPrice == null || carPrice >= minPrice;
      final matchesMax = maxPrice == null || carPrice <= maxPrice;

      return matchesQuery && matchesMin && matchesMax;
    }).toList();
  }

  void _registerSearch(String term) {
    if (term.trim().isEmpty) return;
    setState(() {
      _recentSearches.remove(term);
      _recentSearches.insert(0, term);
      if (_recentSearches.length > 8) _recentSearches.removeLast();
    });
  }

  void _selectTerm(String term) {
    _controller.text = term;
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: term.length));
    _registerSearch(term);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // CarsProvider.cars — полный список опубликованных объявлений
    // (тот же источник, что использует Главная).
    final allPublishedCars = context.watch<CarsProvider>().cars;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            SearchBarWidget(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: () => setState(() {}),
              onSubmitted: _registerSearch,
            ),
            _FilterChipsRow(
              current: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            PriceFilterWidget(
              minController: _minPriceController,
              maxController: _maxPriceController,
              onChanged: () => setState(() {}),
              onClear: () => setState(() {
                _minPriceController.clear();
                _maxPriceController.clear();
              }),
            ),
            Expanded(
              child: _hasActiveFilter()
                  ? SearchResultsWidget(
                      results: _getFilteredCars(allPublishedCars),
                      filter: _filter,
                      )
                  : SuggestionsViewWidget(
                      recentSearches: _recentSearches,
                      categories: _categories,
                      brands: _brands,
                      onSelect: _selectTerm,
                      onRemoveRecent: (term) =>
                          setState(() => _recentSearches.remove(term)),
                      onClearRecent: () =>
                          setState(() => _recentSearches.clear()),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipsRow extends StatelessWidget {
  final ResultFilter current;
  final ValueChanged<ResultFilter> onChanged;

  const _FilterChipsRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = const [
      (ResultFilter.all, 'Всё', Icons.apps_rounded),
      (ResultFilter.video, 'Только видео', Icons.play_circle_fill_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final (value, label, icon) = options[i];
            final selected = current == value;
            return GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF2D1B6E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF2D1B6E)
                        : const Color(0xFFE0E0E0),
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 16,
                        color: selected ? Colors.white : Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}