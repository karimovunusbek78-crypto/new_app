import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class FeaturedCarsList extends StatelessWidget {
  const FeaturedCarsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Популярные авто',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3A6FF8),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Все',
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
        SizedBox(height: 1.5.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w),
          child: Column(
            children: [
              const FeaturedCarCard(
                name: 'BMW M4',
                year: '2025',
                km: '12 500 км',
                price: '65 000 \$',
                transmission: 'Автомат',
              ),
              SizedBox(height: 1.5.h),
              const FeaturedCarCard(
                name: 'Audi RS7',
                year: '2024',
                km: '8 300 км',
                price: '79 000 \$',
                transmission: 'Автомат',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FeaturedCarCard extends StatefulWidget {
  final String name;
  final String year;
  final String km;
  final String price;
  final String transmission;

  const FeaturedCarCard({
    super.key,
    required this.name,
    required this.year,
    required this.km,
    required this.price,
    required this.transmission,
  });

  @override
  State<FeaturedCarCard> createState() => _FeaturedCarCardState();
}

class _FeaturedCarCardState extends State<FeaturedCarCard> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
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
          Container(
            width: 24.w,
            height: 9.h,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(3.w),
            ),
            child: Icon(
              Icons.directions_car,
              size: 4.h,
              color: const Color(0xFFAEAEB2),
            ),
          ),
          SizedBox(width: 3.5.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  '${widget.year} • ${widget.km}',
                  style: TextStyle(
                      fontSize: 12.sp, color: const Color(0xFF8E8E93)),
                ),
                SizedBox(height: 0.6.h),
                Text(
                  widget.price,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3A6FF8),
                  ),
                ),
                SizedBox(height: 0.6.h),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  child: Text(
                    widget.transmission,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: const Color(0xFF636366),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _liked = !_liked),
            child: Icon(
              _liked ? Icons.favorite : Icons.favorite_border,
              color:
                  _liked ? const Color(0xFF3A6FF8) : const Color(0xFF8E8E93),
              size: 2.5.h,
            ),
          ),
        ],
      ),
    );
  }
}