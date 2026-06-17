import 'package:flutter/material.dart';
import 'package:new_app/src/pages/favorite/providers/favorites_provider.dart';
import 'package:new_app/src/pages/home/models/car.dart';
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
                padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.4.h),
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
          ? const _EmptyState()
          : filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 6.h, color: const Color(0xFFAEAEB2)),
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
                  itemBuilder: (context, index) => _FavoriteCarCard(
                    car: filtered[index],
                  ),
                ),
    );
  }
}

// ── Пустое состояние ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18.w,
            height: 18.w,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              size: 7.h,
              color: const Color(0xFFAEAEB2),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Нет избранных авто',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Нажмите ♡ на карточке авто,\nчтобы добавить в избранное',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFF8E8E93),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Карточка авто ────────────────────────────────────────────────
class _FavoriteCarCard extends StatelessWidget {
  final Car car;
  const _FavoriteCarCard({required this.car});

  @override
  Widget build(BuildContext context) {
    final liked = context.watch<FavoritesProvider>().isFavorite(car);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Превью ──
          Container(
            width: double.infinity,
            height: 15.h,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4.5.w),
                topRight: Radius.circular(4.5.w),
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.directions_car_rounded,
                    size: 7.h,
                    color: const Color(0xFFC7C7CC),
                  ),
                ),
                // Бейдж топлива
                Positioned(
                  top: 1.2.h,
                  left: 3.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 2.5.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Text(
                      car.fuelType,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3A6FF8),
                      ),
                    ),
                  ),
                ),
                // Кнопка сердечка
                Positioned(
                  top: 0.8.h,
                  right: 2.5.w,
                  child: GestureDetector(
                    onTap: () =>
                        context.read<FavoritesProvider>().toggleFavorite(car),
                    child: Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: liked
                            ?  Colors.red
                            : const Color(0xFF8E8E93),
                        size: 2.2.h,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Контент ──
          Padding(
            padding: EdgeInsets.all(3.5.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            car.name,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1C1C1E),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 0.4.h),
                          Text(
                            '${car.year} · ${car.km}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      car.price,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF3A6FF8),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 1.2.h),

                // Теги
                Wrap(
                  spacing: 1.5.w,
                  runSpacing: 0.8.h,
                  children: [
                    _Tag(text: car.transmission, icon: Icons.settings_rounded),
                    _Tag(text: car.engineCapacity, icon: Icons.speed_rounded),
                    _Tag(text: car.bodyType, icon: Icons.directions_car_rounded),
                    _Tag(text: car.color, icon: Icons.circle_rounded),
                  ],
                ),

                SizedBox(height: 1.2.h),

                const Divider(color: Color(0xFFF2F2F7), thickness: 1),

                SizedBox(height: 0.8.h),

                // Локация
                Row(
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 1.8.h, color: const Color(0xFF8E8E93)),
                    SizedBox(width: 1.w),
                    Text(
                      car.location,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF8E8E93),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Тег ──────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Tag({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(2.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 1.5.h, color: const Color(0xFF8E8E93)),
          SizedBox(width: 1.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF48484A),
            ),
          ),
        ],
      ),
    );
  }
}