import 'package:get/get.dart';

import '../../../helper/AppSnackbar.dart';
import '../../../services/RecommendationService.dart';
import '../../shopping_input/model/ShoppingRequestModel.dart';
import '../model/RecommendationResultModel.dart';

class RecommendationController extends GetxController {
  final RecommendationService _recommendationService =
      const RecommendationService();
  final Rxn<RecommendationResultModel> recommendationResult =
      Rxn<RecommendationResultModel>();
  final RxBool isLoading = false.obs;
  final Rxn<ShoppingRequestModel> request = Rxn<ShoppingRequestModel>();
  final RxString postcode = ''.obs;
  final RxList<String> shoppingItems = <String>[].obs;
  final RxDouble budget = 0.0.obs;
  int _loadToken = 0;

  @override
  void onInit() {
    super.onInit();
    _loadFromArguments();
  }

  void _loadFromArguments() {
    final ShoppingRequestModel? incomingRequest =
        Get.arguments as ShoppingRequestModel?;

    if (incomingRequest == null) {
      resetState();
      return;
    }

    request.value = incomingRequest;
    postcode.value = incomingRequest.postcode;
    shoppingItems.assignAll(
      incomingRequest.shoppingItems
          .split(',')
          .map((String item) => item.trim().toLowerCase())
          .where((String item) => item.isNotEmpty)
          .toList(),
    );
    budget.value =
        double.tryParse(
          incomingRequest.budget.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0;
    loadRecommendations();
  }

  Future<void> loadRecommendations() async {
    if (request.value == null || isLoading.value) {
      return;
    }

    final int loadToken = ++_loadToken;
    isLoading.value = true;
    recommendationResult.value = null;

    try {
      recommendationResult.value = await _recommendationService
          .getRecommendations(
            postcode: postcode.value,
            shoppingItems: shoppingItems.toList(),
            budget: budget.value,
            userLatitude: request.value?.userLatitude,
            userLongitude: request.value?.userLongitude,
          );
      if (isClosed || loadToken != _loadToken) {
        return;
      }
    } catch (error) {
      if (isClosed || loadToken != _loadToken) {
        return;
      }

      recommendationResult.value = null;
      CustomErrorSnackbar.showError(
        title: 'Recommendation',
        message: 'Unable to load recommendations right now.',
      );
    } finally {
      if (!isClosed && loadToken == _loadToken) {
        isLoading.value = false;
      }
    }
  }

  void resetState() {
    recommendationResult.value = null;
    request.value = null;
    postcode.value = '';
    shoppingItems.clear();
    budget.value = 0;
    isLoading.value = false;
  }

  @override
  void onClose() {
    _loadToken++;
    resetState();
    super.onClose();
  }
}
