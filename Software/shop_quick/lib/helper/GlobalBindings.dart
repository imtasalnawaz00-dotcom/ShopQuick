import 'package:get/get.dart';
import 'package:shop_quick/modules/favourite_stores/controller/FavouriteStoreController.dart';
import '../modules/main_navigation/controller/MainNavigationController.dart';
import '../modules/my_receipts/controller/MyReceiptsController.dart';
import '../modules/recommendations/controller/RecommendationController.dart';
import '../modules/receipt_upload/controller/ReceiptUploadController.dart';
import '../modules/shopping_input/controller/ShoppingInputController.dart';

class GlobalBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainNavigationController>(() => MainNavigationController());
    Get.lazyPut<ShoppingInputController>(() => ShoppingInputController());
    Get.lazyPut<FavouriteStoresController>(() => FavouriteStoresController());
    Get.lazyPut<MyReceiptsController>(() => MyReceiptsController());
    Get.lazyPut<RecommendationController>(() => RecommendationController(), fenix: true,);
    Get.lazyPut<ReceiptUploadController>(() => ReceiptUploadController());
  }
}
