import 'package:get/get.dart';

import '../../../services/DatabaseService.dart';
import '../../recommendations/model/StoreTotalModel.dart';
import '../model/SavedStoreItemModel.dart';
import '../model/SavedStoreModel.dart';

class FavouriteStoresController extends GetxController {
  FavouriteStoresController();

  static const String currentUserKey = 'user_1';

  final DatabaseService _databaseService = DatabaseService.instance;
  final RxList<SavedStoreModel> savedStores = <SavedStoreModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadSavedStores();
  }

  Future<void> loadSavedStores() async {
    isLoading.value = true;
    savedStores.value = await _databaseService.fetchFavouriteStores(
      userKey: currentUserKey,
    );
    isLoading.value = false;
  }

  Future<void> saveRecommendedStore({
    required String storeName,
    required String storePostcode,
    required double basketTotal,
    required List<MatchedItemModel> items,
  }) async {
    await _databaseService.saveFavouriteStore(
      userKey: currentUserKey,
      storeName: storeName,
      storePostcode: storePostcode,
      basketTotal: basketTotal,
      items: items
          .map(
            (MatchedItemModel item) => SavedStoreItemModel(
              id: 0,
              savedStoreId: 0,
              itemName: item.name,
              price: item.price,
            ),
          )
          .toList(),
    );
    await loadSavedStores();
  }

  Future<void> deleteSavedItem(int savedStoreItemId) async {
    await _databaseService.deleteFavouriteStoreItem(
      savedStoreItemId: savedStoreItemId,
      userKey: currentUserKey,
    );
    await loadSavedStores();
  }
}
