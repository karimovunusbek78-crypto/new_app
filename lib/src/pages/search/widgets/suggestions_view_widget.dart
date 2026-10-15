import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'recent_searches_widget.dart';
import 'category_grid_widget.dart';
import 'brand_list_widget.dart';

class SuggestionsViewWidget extends StatelessWidget {
  final List<String> recentSearches;
  final List<CarCategory> categories;
  final List<CarBrand> brands;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecent;

  const SuggestionsViewWidget({
    super.key,
    required this.recentSearches,
    required this.categories,
    required this.brands,
    required this.onSelect,
    required this.onRemoveRecent,
    required this.onClearRecent,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 3.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recentSearches.isNotEmpty) ...[
            RecentSearchesWidget(
              items: recentSearches,
              onSelect: onSelect,
              onRemove: onRemoveRecent,
              onClearAll: onClearRecent,
            ),
            SizedBox(height: 3.h),
          ],
          _SectionHeader(title: 'Типы кузова'),
          SizedBox(height: 1.5.h),
          CategoryGridWidget(categories: categories, onSelect: onSelect),
          SizedBox(height: 3.h),
          _SectionHeader(title: 'Популярные марки'),
          SizedBox(height: 1.5.h),
          BrandListWidget(brands: brands, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
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
}
