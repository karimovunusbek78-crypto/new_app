import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/models/cars_data.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:new_app/src/pages/home/widgets/featured_cars_list.dart'; // for FeaturedCarCard

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _CarCategory {
  final String label;
  final IconData icon;
  const _CarCategory(this.label, this.icon);
}

class _Brand {
  final String name;
  final String logoPath;
  const _Brand(this.name, this.logoPath);
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  final List<String> _recentSearches = [
    'BMW M4',
    'Audi RS7 2024',
    'Tesla Model 3',
  ];

  final List<_CarCategory> _categories = const [
    _CarCategory('Седан', Icons.directions_car),
    _CarCategory('Внедорожник', Icons.directions_car_filled),
    _CarCategory('Хэтчбэк', Icons.commute),
    _CarCategory('Купе', Icons.time_to_leave),
    _CarCategory('Кроссовер', Icons.terrain),
    _CarCategory('Минивэн', Icons.airport_shuttle),
    _CarCategory('Пикап', Icons.local_shipping),
    _CarCategory('Электро', Icons.electric_bolt),
  ];

  final List<_Brand> _brands = const [
    _Brand('BMW', 'assets/images/bmw.png'),
    _Brand('Audi', 'assets/images/audi.png'),
    _Brand('Mercedes', 'assets/images/mersedes.png'),
    _Brand('Toyota', 'assets/images/toyota.png'),
    _Brand('Lexus', 'assets/images/lexus.png'),
    _Brand('Kia', 'assets/images/kia.png'),
    _Brand('Hyundai', 'assets/images/hyundai.png'),
    _Brand('Tesla', 'assets/images/tesla.png'),
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

  // Pulls the digits out of strings like "65 000 $" -> 65000
  double _parsePrice(String price) {
    final digitsOnly = price.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return 0;
    return double.parse(digitsOnly);
  }

  bool _hasActiveFilter() {
    return _controller.text.trim().isNotEmpty ||
        _minPriceController.text.trim().isNotEmpty ||
        _maxPriceController.text.trim().isNotEmpty;
  }

  List<Car> _getFilteredCars() {
    final q = _controller.text.trim().toLowerCase();
    final minPrice = double.tryParse(_minPriceController.text.trim());
    final maxPrice = double.tryParse(_maxPriceController.text.trim());

    return allCars.where((car) {
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
  }

  void _removeRecent(String term) {
    setState(() => _recentSearches.remove(term));
  }

  void _clearPriceFilter() {
    setState(() {
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = _hasActiveFilter();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            _buildPriceFilterRow(),
            Expanded(
              child: hasActiveFilter ? _buildResults() : _buildSuggestions(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Строка поиска ──────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 1.5.h),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 6.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3.5.w),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(width: 3.5.w),
                  Icon(Icons.search,
                      color: const Color(0xFF8E8E93), size: 2.4.h),
                  SizedBox(width: 2.5.w),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _registerSearch,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                          fontSize: 14.sp, color: const Color(0xFF1C1C1E)),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        hintText: 'Поиск авто, марок или моделей...',
                        hintStyle: TextStyle(
                            fontSize: 14.sp, color: const Color(0xFFAEAEB2)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _controller.clear()),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3.w),
                        child: Icon(Icons.close,
                            color: const Color(0xFF8E8E93), size: 2.2.h),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Фильтр по цене (от / до) ────────────────────────────────────────────
  Widget _buildPriceFilterRow() {
    final hasPriceFilter = _minPriceController.text.isNotEmpty ||
        _maxPriceController.text.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 1.5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _buildPriceField(
              controller: _minPriceController,
              label: 'Цена от',
              hint: '0',
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: _buildPriceField(
              controller: _maxPriceController,
              label: 'Цена до',
              hint: '100 000',
            ),
          ),
          if (hasPriceFilter) ...[
            SizedBox(width: 2.5.w),
            GestureDetector(
              onTap: _clearPriceFilter,
              child: Container(
                width: 6.h,
                height: 6.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.close,
                    size: 2.2.h, color: const Color(0xFF8E8E93)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 1.w, bottom: 0.6.h),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8E8E93),
            ),
          ),
        ),
        Container(
          height: 6.h,
          padding: EdgeInsets.symmetric(horizontal: 3.5.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3.w),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.attach_money,
                  size: 2.h, color: const Color(0xFF3A6FF8)),
              SizedBox(width: 1.w),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFAEAEB2),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Подсказки: недавние, категории, бренды ───────────────────────────────
  Widget _buildSuggestions() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 3.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            _buildRecentSearches(),
            SizedBox(height: 3.h),
          ],
          _buildSectionHeader('Типы кузова'),
          SizedBox(height: 1.5.h),
          _buildCategoryGrid(),
          SizedBox(height: 3.h),
          _buildSectionHeader('Популярные марки'),
          SizedBox(height: 1.5.h),
          _buildBrandList(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1C1C1E),
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Недавние запросы',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _recentSearches.clear()),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3A6FF8),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Очистить',
                    style: TextStyle(
                        fontSize: 13.sp, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          SizedBox(height: 1.2.h),
          Wrap(
            spacing: 2.5.w,
            runSpacing: 1.2.h,
            children: _recentSearches.map((term) {
              return GestureDetector(
                onTap: () => _selectTerm(term),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.w),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history,
                          size: 1.9.h, color: const Color(0xFF8E8E93)),
                      SizedBox(width: 1.5.w),
                      Text(term,
                          style: TextStyle(
                              fontSize: 13.sp,
                              color: const Color(0xFF1C1C1E))),
                      SizedBox(width: 1.5.w),
                      GestureDetector(
                        onTap: () => _removeRecent(term),
                        child: Icon(Icons.close,
                            size: 1.7.h, color: const Color(0xFFAEAEB2)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _categories.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 4.w,
          crossAxisSpacing: 5.w,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return GestureDetector(
            onTap: () => _selectTerm(category.label),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4.w),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(category.icon,
                      size: 2.8.h, color: const Color(0xFF3A6FF8)),
                  SizedBox(height: 0.8.h),
                  Text(
                    category.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrandList() {
    return SizedBox(
      height: 11.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 5.w),
        itemCount: _brands.length,
        separatorBuilder: (_, __) => SizedBox(width: 4.w),
        itemBuilder: (context, index) {
          final brand = _brands[index];
          return GestureDetector(
            onTap: () => _selectTerm(brand.name),
            child: Column(
              children: [
                Container(
                  width: 9.h,
                  height: 7.h,
                  padding: EdgeInsets.all(1.2.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    brand.logoPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Falls back to the first letter if the PNG is missing
                      return Center(
                        child: Text(
                          brand.name.substring(0, 1),
                          style: TextStyle(
                            fontSize: 40.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 0.8.h),
                Text(brand.name,
                    style: TextStyle(
                        fontSize: 11.sp, color: const Color(0xFF1C1C1E))),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Реальные результаты поиска ───────────────────────────────────────────
  Widget _buildResults() {
    final results = _getFilteredCars();

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 6.h, color: const Color(0xFFAEAEB2)),
              SizedBox(height: 2.h),
              Text(
                'Ничего не найдено',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'Попробуйте изменить запрос или диапазон цен',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 3.h),
      itemCount: results.length,
      separatorBuilder: (_, __) => SizedBox(height: 1.5.h),
      itemBuilder: (context, index) => FeaturedCarCard(car: results[index]),
    );
  }
}