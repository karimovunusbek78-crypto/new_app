import 'package:flutter/material.dart';
import 'package:new_app/src/pages/favorite/proget/empty_state.dart';
import 'package:new_app/src/pages/favorite/proget/favorite_car_card.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
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
    // Единый источник правды: лайкнутые авто из CarsProvider, тот же,
    // что и в видео-ленте, на Home и на странице деталей.
    final favorites = context.watch<CarsProvider>().likedCars;

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
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Text(
              'Избранное',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C1C1E),
                letterSpacing: -0.5,
              ),
            ),
            if (favorites.isNotEmpty) ...[
              SizedBox(width: 2.w),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 2.5.w,
                  vertical: 0.4.h,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${favorites.length}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ),
            ],
          ],
        ),
        bottom: favorites.isNotEmpty
            ? PreferredSize(
                preferredSize: Size.fromHeight(6.5.h),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.5.h),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFF1C1C1E),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Поиск по избранному',
                        hintStyle: TextStyle(
                          fontSize: 14.sp,
                          color: const Color(0xFF8E8E93),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: const Color(0xFF8E8E93),
                          size: 2.4.h,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(
                                  Icons.cancel_rounded,
                                  color: const Color(0xFFAEAEB2),
                                  size: 2.2.h,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 1.3.h,
                          horizontal: 3.w,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: favorites.isEmpty
          ? const EmptyState()
          : filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 6.h,
                        color: const Color(0xFFAEAEB2),
                      ),
                      SizedBox(height: 1.5.h),
                      Text(
                        'Ничего не найдено',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3C3C43),
                        ),
                      ),
                      SizedBox(height: 0.8.h),
                      Text(
                        'Попробуйте другой запрос',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => SizedBox(height: 1.5.h),
                  itemBuilder: (context, index) =>
                      FavoriteCarCard(car: filtered[index]),
                ),
    );
  }
}