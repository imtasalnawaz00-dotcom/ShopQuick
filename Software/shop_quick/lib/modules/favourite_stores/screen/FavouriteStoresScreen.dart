import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/screen_header.dart';
import '../../../widgets/section_card.dart';
import '../controller/FavouriteStoreController.dart';
import '../model/SavedStoreItemModel.dart';
import '../model/SavedStoreModel.dart';

class FavouriteStoresScreen extends GetView<FavouriteStoresController> {
  const FavouriteStoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg.w,
              AppSpacing.lg.h,
              AppSpacing.lg.w,
              AppSpacing.xxl.h,
            ),
            itemCount: controller.savedStores.isEmpty
                ? 2
                : controller.savedStores.length + 1,
            separatorBuilder: (_, __) => SizedBox(height: AppSpacing.lg.h),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return const ScreenHeader(
                  title: 'Favourite Stores',
                  subtitle: 'Your saved store baskets in one place',
                  showBackButton: false,
                );
              }

              if (controller.savedStores.isEmpty) {
                return const _FavouriteStoresEmptyState();
              }

              final SavedStoreModel store = controller.savedStores[index - 1];
              return _FavouriteStoreCard(
                store: store,
                onDeleteItem: _confirmDeleteItem,
              );
            },
          );
        }),
      ),
    );
  }

  Future<void> _confirmDeleteItem(int savedStoreItemId) async {
    final bool? shouldDelete = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        titlePadding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 12.h),
        contentPadding: EdgeInsets.fromLTRB(22.w, 0, 22.w, 10.h),
        actionsPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
        title: Text(
          'Delete Item',
          style: AppTextStyles.titleLarge.copyWith(fontSize: 18.sp),
        ),
        content: Text(
          'Are you sure you want to delete this item from the favourite store list?',
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 14.sp,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Cancel',
              style: AppTextStyles.titleMedium.copyWith(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              'Delete',
              style: AppTextStyles.titleMedium.copyWith(
                fontSize: 14.sp,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await controller.deleteSavedItem(savedStoreItemId);
    }
  }
}

class _FavouriteStoreCard extends StatelessWidget {
  const _FavouriteStoreCard({
    required this.store,
    required this.onDeleteItem,
  });

  final SavedStoreModel store;
  final ValueChanged<int> onDeleteItem;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.storeName,
                      style: AppTextStyles.titleLarge.copyWith(fontSize: 19.sp),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      store.storePostcode.isNotEmpty
                          ? store.storePostcode
                          : '${store.items.length} item${store.items.length == 1 ? '' : 's'} in basket',
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 9.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '£${store.basketTotal.toStringAsFixed(2)}',
                  style: AppTextStyles.titleMedium.copyWith(fontSize: 14.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: AppDecorations.softSurface.copyWith(
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: store.items
                  .asMap()
                  .entries
                  .map(
                    (MapEntry<int, SavedStoreItemModel> entry) =>
                        _SavedBasketItemRow(
                      item: entry.value,
                      isLast: entry.key == store.items.length - 1,
                      onDelete: () => onDeleteItem(entry.value.id),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedBasketItemRow extends StatelessWidget {
  const _SavedBasketItemRow({
    required this.item,
    required this.isLast,
    required this.onDelete,
  });

  final SavedStoreItemModel item;
  final bool isLast;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppColors.border,
                  width: 0.8.w,
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: AppTextStyles.titleMedium.copyWith(fontSize: 15.sp),
                ),
                SizedBox(height: 5.h),
                Text(
                  '£${item.price.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 13.sp),
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.card.withOpacity(0.72),
            borderRadius: BorderRadius.circular(14.r),
            child: InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(14.r),
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 20.sp,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavouriteStoresEmptyState extends StatelessWidget {
  const _FavouriteStoresEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SectionCard(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg.w,
          vertical: AppSpacing.xxl.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74.w,
              height: 74.h,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 34.sp,
                color: AppColors.primaryDark,
              ),
            ),
            SizedBox(height: AppSpacing.lg.h),
            Text(
              'No favourite stores yet',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(fontSize: 20.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              'Stores you save from recommendations will appear here',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 14.sp),
            ),
          ],
        ),
      ),
    );
  }
}
