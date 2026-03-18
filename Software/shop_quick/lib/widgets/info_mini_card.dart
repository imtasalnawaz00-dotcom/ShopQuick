import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';

class InfoMiniCard extends StatelessWidget {
  const InfoMiniCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.md.h,
      ),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18.sp),
            SizedBox(height: 8.h),
          ],
          Text(
            label,
            style: AppTextStyles.label.copyWith(fontSize: 12.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}
