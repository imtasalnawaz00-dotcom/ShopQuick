import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

enum _SnackbarType {
  success,
  error,
  info,
}

class CustomErrorSnackbar {
  CustomErrorSnackbar._();

  static void showError({
    required String message,
    String title = 'Error',
  }) {
    _AppSnackbar.show(
      type: _SnackbarType.error,
      title: title,
      message: message,
    );
  }
}

class CustomSuccessSnackbar {
  CustomSuccessSnackbar._();

  static void showSuccess({
    required String message,
    String title = 'Success',
  }) {
    _AppSnackbar.show(
      type: _SnackbarType.success,
      title: title,
      message: message,
    );
  }
}

class CustomInfoSnackbar {
  CustomInfoSnackbar._();

  static void showInfo({
    required String message,
    String title = 'Info',
  }) {
    _AppSnackbar.show(
      type: _SnackbarType.info,
      title: title,
      message: message,
    );
  }
}

class _AppSnackbar {
  _AppSnackbar._();

  static void show({
    required _SnackbarType type,
    required String message,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    final _SnackbarVisuals visuals = _visualsFor(type);

    Get.rawSnackbar(
      snackStyle: SnackStyle.FLOATING,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.transparent,
      margin: EdgeInsets.fromLTRB(18.w, 0, 18.w, 16.h),
      padding: EdgeInsets.zero,
      borderRadius: 0,
      boxShadows: const <BoxShadow>[],
      isDismissible: true,
      duration: const Duration(seconds: 3),
      messageText: Container(
        decoration: BoxDecoration(
          color: visuals.backgroundColor,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: visuals.borderColor),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 18.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38.w,
                height: 38.h,
                decoration: BoxDecoration(
                  color: visuals.iconSurfaceColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  visuals.icon,
                  size: 20.sp,
                  color: visuals.iconColor,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null && title.trim().isNotEmpty) ...[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 15.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                    ],
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionLabel != null &&
                  actionLabel.trim().isNotEmpty &&
                  onAction != null) ...[
                SizedBox(width: 10.w),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontSize: 13.sp,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static _SnackbarVisuals _visualsFor(_SnackbarType type) {
    switch (type) {
      case _SnackbarType.success:
        return const _SnackbarVisuals(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.success,
          iconSurfaceColor: Color(0xFFEAF5EF),
          backgroundColor: AppColors.card,
          borderColor: AppColors.border,
        );
      case _SnackbarType.error:
        return const _SnackbarVisuals(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          iconSurfaceColor: Color(0xFFFEF0EE),
          backgroundColor: AppColors.card,
          borderColor: AppColors.border,
        );
      case _SnackbarType.info:
        return const _SnackbarVisuals(
          icon: Icons.info_outline_rounded,
          iconColor: AppColors.primaryDark,
          iconSurfaceColor: AppColors.primaryLight,
          backgroundColor: AppColors.card,
          borderColor: AppColors.border,
        );
    }
  }
}

class _SnackbarVisuals {
  const _SnackbarVisuals({
    required this.icon,
    required this.iconColor,
    required this.iconSurfaceColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconSurfaceColor;
  final Color backgroundColor;
  final Color borderColor;
}
