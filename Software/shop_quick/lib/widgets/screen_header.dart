import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = false,
  });

  final String title;
  final String? subtitle;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBackButton) ...[
          InkWell(
            onTap: Get.back,
            borderRadius: BorderRadius.circular(18.r),
            child: Container(
              width: 42.w,
              height: 42.h,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md.w),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment:
                showBackButton ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: showBackButton ? TextAlign.start : TextAlign.center,
                style: AppTextStyles.headingMedium.copyWith(fontSize: 24.sp),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text(
                  subtitle!,
                  textAlign:
                      showBackButton ? TextAlign.start : TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 13.sp),
                ),
              ],
            ],
          ),
        ),
        if (showBackButton) SizedBox(width: 42.w),
      ],
    );
  }
}
