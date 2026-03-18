import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/PrimaryButton.dart';
import '../../../widgets/screen_header.dart';
import '../../../widgets/section_card.dart';
import '../controller/MyReceiptsController.dart';
import '../model/UploadedReceiptModel.dart';

class MyReceiptsScreen extends GetView<MyReceiptsController> {
  const MyReceiptsScreen({super.key});

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
            itemCount: controller.receipts.isEmpty
                ? 2
                : controller.receipts.length + 1,
            separatorBuilder: (_, __) => SizedBox(height: AppSpacing.lg.h),
            itemBuilder: (_, int index) {
              if (index == 0) {
                return const ScreenHeader(
                  title: 'My Receipts',
                  subtitle: 'View and manage your uploaded receipt history',
                  showBackButton: false,
                );
              }

              if (controller.receipts.isEmpty) {
                return const _MyReceiptsEmptyState();
              }

              final UploadedReceiptModel receipt = controller.receipts[index - 1];
              return _ReceiptCard(
                receipt: receipt,
                onSeeReceipt: () => controller.openReceiptPreview(receipt),
                onSeeAddedText: () => controller.openExtractedDataPreview(receipt),
                onDelete: () => _confirmDeleteReceipt(receipt),
              );
            },
          );
        }),
      ),
    );
  }

  Future<void> _confirmDeleteReceipt(UploadedReceiptModel receipt) async {
    final bool? shouldDelete = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        titlePadding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 10.h),
        contentPadding: EdgeInsets.fromLTRB(22.w, 0, 22.w, 8.h),
        actionsPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
        title: Text(
          'Delete Receipt',
          style: AppTextStyles.titleLarge.copyWith(fontSize: 18.sp),
        ),
        content: Text(
          'Are you sure you want to delete this receipt?',
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
              'Yes, Delete',
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
      await controller.deleteReceipt(receipt);
    }
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.receipt,
    required this.onSeeReceipt,
    required this.onSeeAddedText,
    required this.onDelete,
  });

  final UploadedReceiptModel receipt;
  final VoidCallback onSeeReceipt;
  final VoidCallback onSeeAddedText;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18.r),
            child: Container(
              width: double.infinity,
              height: 190.h,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: receipt.imagePath != null && receipt.imagePath!.isNotEmpty
                  ? Image.file(
                      File(receipt.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildMissingPreview(),
                    )
                  : _buildMissingPreview(),
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          Text(
            receipt.storeName,
            style: AppTextStyles.titleLarge.copyWith(fontSize: 20.sp),
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16.sp,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  _formatUploadedDate(receipt.uploadedAt),
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 13.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),
          Column(
            children: [
              PrimaryButton(
                text: 'See Receipt',
                textColor: Colors.white,
                onPressed: onSeeReceipt,
                height: 48,
                icon: Icons.visibility_outlined,
              ),

              SizedBox(height: AppSpacing.md,),

              OutlinedButton.icon(
                onPressed: onSeeAddedText,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48.h),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                ),
                icon: Icon(
                  Icons.notes_rounded,
                  size: 18.sp,
                  color: AppColors.textPrimary,
                ),
                label: Text(
                  'See Added Text',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleMedium.copyWith(fontSize: 14.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          OutlinedButton.icon(
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 46.h),
              backgroundColor: const Color(0xFFFFF8F7),
              side: BorderSide(
                color: AppColors.error.withOpacity(0.22),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18.sp,
              color: AppColors.error,
            ),
            label: Text(
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
  }

  Widget _buildMissingPreview() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68.w,
              height: 68.h,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                boxShadow: AppDecorations.card.boxShadow,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 32.sp,
                color: AppColors.primaryDark,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Receipt preview unavailable',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium.copyWith(fontSize: 14.sp),
            ),
          ],
        ),
      ),
    );
  }

  String _formatUploadedDate(DateTime uploadedAt) {
    final String day = uploadedAt.day.toString().padLeft(2, '0');
    final String month = uploadedAt.month.toString().padLeft(2, '0');
    final String year = uploadedAt.year.toString();
    final int hour = uploadedAt.hour % 12 == 0 ? 12 : uploadedAt.hour % 12;
    final String minute = uploadedAt.minute.toString().padLeft(2, '0');
    final String period = uploadedAt.hour >= 12 ? 'PM' : 'AM';
    return 'Uploaded on $day/$month/$year at $hour:$minute $period';
  }
}

class _MyReceiptsEmptyState extends StatelessWidget {
  const _MyReceiptsEmptyState();

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
              width: 76.w,
              height: 76.h,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                size: 36.sp,
                color: AppColors.primaryDark,
              ),
            ),
            SizedBox(height: AppSpacing.lg.h),
            Text(
              'No receipts uploaded yet',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(fontSize: 20.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              'Your uploaded receipts will appear here',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 14.sp),
            ),
          ],
        ),
      ),
    );
  }
}
