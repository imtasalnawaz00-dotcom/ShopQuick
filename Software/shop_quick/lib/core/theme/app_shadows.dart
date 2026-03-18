import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  static const List<BoxShadow> light = <BoxShadow>[
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];
}
