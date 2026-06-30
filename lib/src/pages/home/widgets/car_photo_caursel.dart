import 'dart:io';
import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class CarPhotoCarousel extends StatefulWidget {
  final List<String> photoPaths;
  final double height; // in .h units
  final BorderRadius borderRadius;

  const CarPhotoCarousel({
    super.key,
    required this.photoPaths,
    this.height = 15,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<CarPhotoCarousel> createState() => _CarPhotoCarouselState();
}

class _CarPhotoCarouselState extends State<CarPhotoCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photoPaths;

    if (photos.isEmpty) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: Container(
          width: double.infinity,
          height: widget.height.h,
          color: const Color(0xFFE5E5EA),
          child: Center(
            child: Icon(
              Icons.directions_car_rounded,
              size: 7.h,
              color: const Color(0xFFC7C7CC),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height.h,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final path = photos[i];
                final isNetwork = path.startsWith('http');
                return isNetwork
                    ? Image.network(path, fit: BoxFit.cover, width: double.infinity)
                    : Image.file(File(path), fit: BoxFit.cover, width: double.infinity);
              },
            ),
            if (photos.length > 1)
              Padding(
                padding: EdgeInsets.only(bottom: 1.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(photos.length, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.symmetric(horizontal: 0.5.w),
                      width: active ? 2.2.w : 1.6.w,
                      height: 1.6.w,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(1.h),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}