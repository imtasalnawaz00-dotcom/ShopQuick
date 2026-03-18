import 'package:get/get.dart';

import '../modules/main_navigation/screen/MainNavigationScreen.dart';
import '../modules/recommendations/screen/RecommendationScreen.dart';
import '../modules/receipt_upload/screen/ReceiptUploadScreen.dart';
import '../modules/shopping_input/screen/ShoppingInputScreen.dart';

class Routes {
  static const String splash = '/';
  static const String mainNavigation = '/main-navigation';
  static const String shoppingInput = '/shopping-input';
  static const String recommendations = '/recommendations';
  static const String splitBasket = '/split-basket';
  static const String receiptUpload = '/receipt-upload';

  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage(name: mainNavigation, page: () => const MainNavigationScreen()),
    GetPage(name: shoppingInput, page: () => const ShoppingInputScreen()),
    GetPage(name: recommendations, page: () => const RecommendationScreen()),
    GetPage(name: receiptUpload, page: () => const ReceiptUploadScreen()),
  ];
}
