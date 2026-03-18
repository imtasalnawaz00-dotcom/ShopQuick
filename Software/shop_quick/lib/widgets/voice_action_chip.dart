import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class VoiceActionChip extends StatelessWidget {
  const VoiceActionChip({
    super.key,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.icon = Icons.mic_none_rounded,
  });

  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18.sp,
                color: isActive ? AppColors.primaryDark : AppColors.textSecondary,
              ),
              SizedBox(width: 8.w),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
