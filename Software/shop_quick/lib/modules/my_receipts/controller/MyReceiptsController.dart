import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../helper/AppSnackbar.dart';
import '../../../services/DatabaseService.dart';
import '../model/UploadedReceiptItemModel.dart';
import '../model/UploadedReceiptModel.dart';

class MyReceiptsController extends GetxController {
  static const String currentUserKey = 'user_1';

  final DatabaseService _databaseService = DatabaseService.instance;
  final RxList<UploadedReceiptModel> receipts = <UploadedReceiptModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadReceipts();
  }

  Future<void> loadReceipts() async {
    isLoading.value = true;

    try {
      receipts.assignAll(
        await _databaseService.fetchUploadedReceipts(
          userKey: currentUserKey,
        ),
      );
    } finally {
      isLoading.value = false;
    }
  }

  void openReceiptPreview(UploadedReceiptModel receipt) {
    Get.dialog(
      Builder(
        builder: (BuildContext context) {
          return Dialog(
            insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.r),
              side: const BorderSide(color: AppColors.border),
            ),
            elevation: 0,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 18.h),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(right: 46.w, left: 16.w),
                        child: Column(
                          children: [
                            Text(
                              receipt.storeName,
                              style: AppTextStyles.titleLarge.copyWith(
                                fontSize: 20.sp,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'Pinch to zoom and drag to inspect the full receipt',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 13.sp,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppSpacing.md.h),
                      Flexible(
                        child: receipt.imagePath != null &&
                                receipt.imagePath!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20.r),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(20.r),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: InteractiveViewer(
                                    minScale: 1,
                                    maxScale: 4,
                                    child: SingleChildScrollView(
                                      padding: EdgeInsets.all(8.w),
                                      child: Image.file(
                                        File(receipt.imagePath!),
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            _buildMissingImageState(),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: _buildMissingImageState(),
                              ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: EdgeInsets.all(9.w),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> openExtractedDataPreview(UploadedReceiptModel receipt) async {
    final List<UploadedReceiptItemModel> items =
        await _databaseService.fetchUploadedReceiptItems(
          receiptId: receipt.id,
          userKey: currentUserKey,
        );

    Get.bottomSheet(
      Builder(
        builder: (BuildContext context) {
          return SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.72,
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24.r,
                    offset: Offset(0, -6.h),
                  ),
                ],
                border: const Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44.w,
                      height: 5.h,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Text(
                    'Added Text',
                    style: AppTextStyles.titleLarge.copyWith(fontSize: 20.sp),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    receipt.storeName,
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 14.sp),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: items.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(18.w),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(18.r),
                            ),
                            child: Text(
                              'No extracted items found for this receipt.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 14.sp,
                              ),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, __) => Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: Divider(
                                  height: 1,
                                  thickness: 0.8,
                                  color: AppColors.border,
                                ),
                              ),
                              itemBuilder: (_, int index) {
                                final UploadedReceiptItemModel item =
                                    items[index];
                                return Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.itemName,
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 6.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius:
                                            BorderRadius.circular(999.r),
                                      ),
                                      child: Text(
                                        item.price != null
                                            ? '£${item.price!.toStringAsFixed(2)}'
                                            : '-',
                                        style:
                                            AppTextStyles.titleMedium.copyWith(
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> deleteReceipt(UploadedReceiptModel receipt) async {
    await _databaseService.deleteUploadedReceipt(
      receiptId: receipt.id,
      userKey: currentUserKey,
    );
    await loadReceipts();
    CustomSuccessSnackbar.showSuccess(
      title: 'My Receipts',
      message: 'Receipt removed successfully.',
    );
  }

  Widget _buildMissingImageState() {
    return Container(
      width: double.infinity,
      height: 220.h,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 42.sp,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 10.h),
          Text(
            'Receipt image not available.',
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}
