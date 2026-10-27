import 'package:flutter/material.dart';
import 'package:new_app/src/app/app_theme.dart';
import 'package:new_app/src/app/ui_kit.dart';

class CarCategory {
  final String label;
  final IconData icon;
  final Color color;

  /// true — категория фильтрует по типу топлива (Электро/Гибрид),
  /// false — по типу кузова.
  final bool isFuel;

  const CarCategory(this.label, this.icon, this.color, {this.isFuel = false});
}

class CategoryGridWidget extends StatelessWidget {
  final List<CarCategory> categories;
  final ValueChanged<CarCategory> onSelect;

  const CategoryGridWidget({
    super.key,
    required this.categories,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final cat = categories[index];
        return FadeSlideIn(
          delay: FadeSlideIn.stagger(index, stepMs: 40),
          child: Pressable(
            onTap: () => onSelect(cat),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.softShadow(0.05),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(cat.icon, size: 22, color: cat.color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
