// lib/pages/favorite_page.dart
import 'package:flutter/material.dart';
import 'package:new_app/src/pages/favorite/providers/favorites_provider.dart';
import 'package:new_app/src/pages/home/widgets/featured_cars_list.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>().favorites;

    final filtered = _query.isEmpty
    ? favorites
    : favorites.where((car) {
        final q = _query.toLowerCase();
        return car.name.toLowerCase().contains(q) ||
            car.year.toLowerCase().contains(q) ||
            car.bodyType.toLowerCase().contains(q) ||
            car.color.toLowerCase().contains(q) ||
            car.location.toLowerCase().contains(q) ||
            car.fuelType.toLowerCase().contains(q) ||
            car.engineCapacity.toLowerCase().contains(q) ||
            car.transmission.toLowerCase().contains(q);
      }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Избранное',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1C1C1E),
          ),
        ),
      ),
      body: Column(
        children: [
          if (favorites.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: TextStyle(fontSize: 14.sp, color: const Color(0xFF1C1C1E)),
                decoration: InputDecoration(
                  hintText: 'Поиск по избранному',
                  hintStyle:
                      TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93)),
                  prefixIcon: Icon(Icons.search,
                      color: const Color(0xFF8E8E93), size: 2.5.h),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close,
                              color: const Color(0xFF8E8E93), size: 2.2.h),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 1.2.h, horizontal: 3.w),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3.w),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          Expanded(
            child: favorites.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_border,
                            size: 6.h, color: const Color(0xFFAEAEB2)),
                        SizedBox(height: 1.5.h),
                        Text(
                          'Пока нет избранных авто',
                          style: TextStyle(
                              fontSize: 14.sp, color: const Color(0xFF8E8E93)),
                        ),
                      ],
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Ничего не найдено',
                          style: TextStyle(
                              fontSize: 14.sp, color: const Color(0xFF8E8E93)),
                        ),
                      )
                    : ListView.separated(
                        padding:
                            EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => SizedBox(height: 1.5.h),
                        itemBuilder: (context, index) =>
                            FeaturedCarCard(car: filtered[index]),
                      ),
          ),
        ],
      ),
    );
  }
}