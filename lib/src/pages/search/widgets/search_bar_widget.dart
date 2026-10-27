import 'package:flutter/material.dart';
import 'package:new_app/src/app/app_theme.dart';
import 'package:new_app/src/app/ui_kit.dart';

/// Поле поиска + кнопка фильтров с бейджем количества активных фильтров.
class SearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilterTap;
  final int activeFilters;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onFilterTap,
    this.activeFilters = 0,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    final hasText = widget.controller.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: focused ? AppColors.primary : Colors.transparent,
                  width: 1.6,
                ),
                boxShadow: focused
                    ? AppColors.glow(AppColors.primary, 0.14)
                    : AppColors.softShadow(),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.search_rounded,
                      key: ValueKey(focused),
                      color: focused ? AppColors.primary : AppColors.muted,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      onChanged: (_) => widget.onChanged(),
                      onSubmitted: widget.onSubmitted,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        hintText: 'Марка или модель',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: hasText
                        ? GestureDetector(
                            key: const ValueKey('clear'),
                            onTap: () {
                              widget.controller.clear();
                              widget.onChanged();
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceAlt,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: AppColors.muted,
                                size: 16,
                              ),
                            ),
                          )
                        : const SizedBox(key: ValueKey('empty'), width: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Pressable(
            onTap: widget.onFilterTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: widget.activeFilters > 0
                        ? AppColors.primaryGradient
                        : null,
                    color: widget.activeFilters > 0 ? null : AppColors.ink,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: widget.activeFilters > 0
                        ? AppColors.glow(AppColors.primary, 0.3)
                        : AppColors.softShadow(0.12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (widget.activeFilters > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(widget.activeFilters),
                      tween: Tween(begin: 0.4, end: 1),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.elasticOut,
                      builder: (_, v, child) =>
                          Transform.scale(scale: v, child: child),
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.like,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          '${widget.activeFilters}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
