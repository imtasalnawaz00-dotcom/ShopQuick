import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_shadows.dart';

class AppDecorations {
  static BoxDecoration card = BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    border: Border.all(color: AppColors.border),
    boxShadow: AppShadows.light,
  );

  static BoxDecoration elevatedCard = BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(AppRadius.xl),
    border: Border.all(color: AppColors.border),
    boxShadow: AppShadows.soft,
  );

  static BoxDecoration input = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.md),
    border: Border.all(color: AppColors.border),
  );

  static BoxDecoration softSurface = BoxDecoration(
    color: AppColors.primaryLight,
    borderRadius: BorderRadius.circular(AppRadius.lg),
  );
}
