import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../helper/AppSnackbar.dart';
import '../../../widgets/CustomText.dart';
import '../../../widgets/PrimaryButton.dart';
import '../../../widgets/screen_header.dart';
import '../../../widgets/section_card.dart';
import '../../favourite_stores/controller/FavouriteStoreController.dart';
import '../controller/RecommendationController.dart';
import '../model/RecommendationResultModel.dart';
import '../model/StoreTotalModel.dart';

class RecommendationScreen extends GetView<RecommendationController> {
  const RecommendationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final RecommendationController recommendationController =
        Get.isRegistered<RecommendationController>()
            ? Get.find<RecommendationController>()
            : Get.put(RecommendationController());
    final FavouriteStoresController listController = Get.find<FavouriteStoresController>();
    final String displayPostcode = recommendationController.postcode.value;
    final double displayBudget = recommendationController.budget.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        if (recommendationController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final RecommendationResultModel? result =
            recommendationController.recommendationResult.value;

        if (result == null || result.cheapestStore == null) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg.w,
                AppSpacing.lg.h,
                AppSpacing.lg.w,
                AppSpacing.xl.h,
              ),
              child: Column(
                children: [
                  const ScreenHeader(
                    title: 'Recommendation',
                    showBackButton: true,
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(maxWidth: 420.w),
                        padding: EdgeInsets.all(24.w),
                        decoration: AppDecorations.card,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 76.w,
                              height: 76.h,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.store_mall_directory_outlined,
                                size: 36.sp,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            SizedBox(height: AppSpacing.lg.h),
                            CustomText(
                              'No matching stores found',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 10.h),
                            CustomText(
                              'Try adjusting your budget or changing your items to get better results',
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: AppSpacing.lg.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16.w),
                              decoration: AppDecorations.softSurface,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomText(
                                    'Postcode: $displayPostcode',
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(height: 8.h),
                                  CustomText(
                                    'Budget: £${displayBudget.toStringAsFixed(2)}',
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: AppSpacing.lg.h),
                            PrimaryButton(
                              text: 'Try Again',
                              textColor: Colors.white,
                              icon: Icons.refresh_rounded,
                              height: 54,
                              onPressed: Get.back,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final StoreTotalModel cheapestStore = result.cheapestStore!;
        final StoreTotalModel? secondBestStore = result.secondBestStore;
        final bool isWithinBudget = cheapestStore.totalPrice <= displayBudget;
        final double budgetDifference = displayBudget - cheapestStore.totalPrice;
        final double remainingBudget = budgetDifference > 0 ? budgetDifference : 0;
        final double overBudgetAmount =
            budgetDifference < 0 ? budgetDifference.abs() : 0;

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg.w,
              AppSpacing.lg.h,
              AppSpacing.lg.w,
              AppSpacing.xl.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ScreenHeader(
                  title: 'Recommendation',
                  showBackButton: true,
                ),
                SizedBox(height: AppSpacing.lg.h),
                CustomText(
                  'Best basket match for your budget',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                SizedBox(height: 6.h),
                CustomText(
                  'Here’s the most cost-effective option near you',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: AppSpacing.lg.h),
                _RecommendationInfoCard(
                  storeName: cheapestStore.storeName,
                  distanceMiles: cheapestStore.distanceMiles,
                  basketTotal: cheapestStore.totalPrice,
                  savingsAmount: remainingBudget,
                  budgetStatus: isWithinBudget
                      ? 'In My Budget'
                      : 'Over Budget',
                  isWithinBudget: isWithinBudget,
                  matchedItems: cheapestStore.matchedItems,
                  matchedItemDetails: cheapestStore.matchedItemDetails,
                  missingItems: cheapestStore.missingItems,
                ),
                SizedBox(height: AppSpacing.lg.h),
                PrimaryButton(
                  text: 'Add to Favourite store',
                  textColor: Colors.white,
                  icon: Icons.favorite_border_rounded,
                  height: 56,
                  onPressed: () async {
                    final List<MatchedItemModel> itemsToSave =
                        cheapestStore.matchedItemDetails.isNotEmpty
                        ? cheapestStore.matchedItemDetails
                        : cheapestStore.matchedItems
                              .map(
                                (String item) => MatchedItemModel(
                                  name: item,
                                  price: 0,
                                ),
                              )
                              .toList();

                    await listController.saveRecommendedStore(
                      storeName: cheapestStore.storeName,
                      storePostcode: cheapestStore.postcode,
                      basketTotal: cheapestStore.totalPrice,
                      items: itemsToSave,
                    );

                    CustomSuccessSnackbar.showSuccess(
                      title: 'Saved',
                      message: 'Recommended items added to your Favourite Stores.',
                    );
                  },
                ),
                SizedBox(height: 28.h),
                const CustomText(
                  'Ranked Alternatives',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                SizedBox(height: 12.h),
                _StoreRankTile(
                  rank: 1,
                  store: cheapestStore,
                  showBestBadge: true,
                ),
                if (secondBestStore != null) ...[
                  SizedBox(height: 12.h),
                  _StoreRankTile(rank: 2, store: secondBestStore),
                ],
                SizedBox(height: AppSpacing.lg.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: AppDecorations.softSurface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        'Postcode: $displayPostcode',
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 8.h),
                      CustomText(
                        'Budget: £${displayBudget.toStringAsFixed(2)}',
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _RecommendationInfoCard extends StatelessWidget {
  const _RecommendationInfoCard({
    required this.storeName,
    required this.distanceMiles,
    required this.basketTotal,
    required this.savingsAmount,
    required this.budgetStatus,
    required this.isWithinBudget,
    required this.matchedItems,
    required this.matchedItemDetails,
    required this.missingItems,
  });

  final String storeName;
  final double? distanceMiles;
  final double basketTotal;
  final double savingsAmount;
  final String budgetStatus;
  final bool isWithinBudget;
  final List<String> matchedItems;
  final List<MatchedItemModel> matchedItemDetails;
  final List<String> missingItems;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.primaryDark.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: SectionCard(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomText(storeName, fontSize: 22, fontWeight: FontWeight.w700),
            if (distanceMiles != null) ...[
              SizedBox(height: 10.h),
              _DistanceChip(distanceMiles: distanceMiles!),
            ],
            SizedBox(height: 14.h),
            CustomText(
              'Basket Total',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 4.h),
            CustomText(
              '£${basketTotal.toStringAsFixed(2)}',
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    'My Savings:',
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  SizedBox(height: 2.h),
                  CustomText(
                    '£${savingsAmount.toStringAsFixed(2)}',
                    fontSize: 14,
                    color: isWithinBudget
                        ? AppColors.success
                        : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                  SizedBox(height: 10.h),
                  CustomText(
                    'Budget Status:',
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  SizedBox(height: 2.h),
                  CustomText(
                    budgetStatus,
                    fontSize: 14,
                    color: isWithinBudget
                        ? AppColors.success
                        : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),
            const CustomText(
              'Matched Items',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            SizedBox(height: 10.h),
            Column(
              children: (matchedItemDetails.isNotEmpty
                      ? matchedItemDetails
                      : matchedItems
                          .map(
                            (String item) => MatchedItemModel(
                              name: item,
                              price: 0,
                            ),
                          )
                          .toList())
                  .map(
                    (MatchedItemModel item) => Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: _MatchedItemRow(item: item),
                    ),
                  )
                  .toList(),
            ),
            if (missingItems.isNotEmpty) ...[
              SizedBox(height: 16.h),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18.sp,
                    color: Colors.orange.shade700,
                  ),
                  SizedBox(width: 6.w),
                  const CustomText(
                    'Missing Items',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: missingItems
                    .map(
                      (String item) => Chip(
                        backgroundColor: const Color(0xFFFFF3E0),
                        label: CustomText(
                          item,
                          fontSize: 13,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MatchedItemRow extends StatelessWidget {
  const _MatchedItemRow({required this.item});

  final MatchedItemModel item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8.w,
            height: 8.h,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: CustomText(
              item.name,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.border),
            ),
            child: CustomText(
              '£${item.price.toStringAsFixed(2)}',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreRankTile extends StatelessWidget {
  const _StoreRankTile({
    required this.rank,
    required this.store,
    this.showBestBadge = false,
  });

  final int rank;
  final StoreTotalModel store;
  final bool showBestBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.h,
            decoration: BoxDecoration(
              color: rank == 1 ? AppColors.primaryLight : AppColors.surface,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: CustomText(
                '$rank',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  store.storeName,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                if (store.distanceMiles != null) ...[
                  SizedBox(height: 6.h),
                  CustomText(
                    '${store.distanceMiles!.toStringAsFixed(1)} miles away',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ],
                if (showBestBadge) ...[
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: CustomText(
                      'Best Price',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
                SizedBox(height: 4.h),
                CustomText(
                  '£${store.totalPrice.toStringAsFixed(2)}',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                if (store.missingItems.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: store.missingItems
                        .map(
                          (String item) => Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: const Color(0xFFFFF3E0),
                            label: CustomText(
                              item,
                              fontSize: 12,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  const _DistanceChip({required this.distanceMiles});

  final double distanceMiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.place_outlined,
            size: 15.sp,
            color: AppColors.primaryDark,
          ),
          SizedBox(width: 6.w),
          CustomText(
            '${distanceMiles.toStringAsFixed(1)} miles away',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
