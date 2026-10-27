import 'package:flutter/material.dart';
import 'package:new_app/src/app/ui_kit.dart';
import 'recent_searches_widget.dart';
import 'category_grid_widget.dart';
import 'brand_list_widget.dart';

class SuggestionsViewWidget extends StatelessWidget {
  final List<String> recentSearches;
  final List<CarCategory> categories;
  final List<CarBrand> brands;
  final ValueChanged<String> onSelect;
  final ValueChanged<CarCategory> onCategory;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecent;

  const SuggestionsViewWidget({
    super.key,
    required this.recentSearches,
    required this.categories,
    required this.brands,
    required this.onSelect,
    required this.onCategory,
    required this.onRemoveRecent,
    required this.onClearRecent,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        if (recentSearches.isNotEmpty) ...[
          RecentSearchesWidget(
            items: recentSearches,
            onSelect: onSelect,
            onRemove: onRemoveRecent,
            onClearAll: onClearRecent,
          ),
          const SizedBox(height: 28),
        ],
        const SectionHeader(title: 'Популярные марки'),
        const SizedBox(height: 14),
        BrandListWidget(brands: brands, onSelect: onSelect),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Категории'),
        const SizedBox(height: 14),
        CategoryGridWidget(categories: categories, onSelect: onCategory),
      ],
    );
  }
}
