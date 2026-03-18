import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theme/app_decorations.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.padding,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(AppSpacing.lg.w),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: AppTextStyles.titleLarge.copyWith(fontSize: 18.sp),
            ),
          ],
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              subtitle!,
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 13.sp),
            ),
          ],
          if (title != null || subtitle != null) SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }
}
