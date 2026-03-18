import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'constants/Routes.dart';
import 'core/theme/app_theme.dart';
import 'helper/GlobalBindings.dart';

class MyApplication extends StatelessWidget {
  const MyApplication({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          initialRoute: Routes.mainNavigation,
          getPages: Routes.pages,
          initialBinding: GlobalBindings(),
        );
      },
    );
  }
}
