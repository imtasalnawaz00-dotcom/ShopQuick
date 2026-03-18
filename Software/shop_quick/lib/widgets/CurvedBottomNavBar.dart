import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shop_quick/core/theme/app_radius.dart';

import '../core/theme/app_colors.dart';

class CurvedBottomNavBar extends StatelessWidget {
  const CurvedBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<CurvedBottomNavBarItem> items;

  @override
  Widget build(BuildContext context) {
    final double navBarHeight = 88.h ;

    return SafeArea(
      top: false,
      bottom: false,
      child: SizedBox(
        height: navBarHeight,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: navBarHeight,
            decoration: BoxDecoration(
              color: AppColors.navBackground,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
              border: Border.all(color: AppColors.navBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navShadow,
                  blurRadius: 28.r,
                  offset: Offset(0, 12.h),
                ),
              ],
            ),
            child: Row(
              children: List<Widget>.generate(
                items.length,
                (int index) => Expanded(
                  child: _CurvedNavItem(
                    item: items[index],
                    isSelected: currentIndex == index,
                    onTap: () => onTap(index),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CurvedBottomNavBarItem {
  const CurvedBottomNavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _CurvedNavItem extends StatelessWidget {
  const _CurvedNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final CurvedBottomNavBarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20.r),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: EdgeInsets.symmetric(horizontal: 4.w,vertical: 4.h),
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.navSelectedSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.navSelectedGlow,
                      blurRadius: 16.r,
                      offset: Offset(0, 6.h),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.92) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  size: 22.sp,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.navUnselected,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.navUnselected,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
