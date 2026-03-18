import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/CustomText.dart';
import '../../../widgets/CustomTextField.dart';
import '../../../widgets/PrimaryButton.dart';
import '../../../widgets/screen_header.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/voice_action_chip.dart';
import '../controller/ReceiptUploadController.dart';

class ReceiptUploadScreen extends GetView<ReceiptUploadController> {
  const ReceiptUploadScreen({super.key});

  Future<void> _handleReceiptSourceTap(BuildContext context) async {
    final bool canProceed = await controller.validateLocationBeforeReceiptUpload();

    if (!canProceed || !context.mounted) {
      return;
    }

    await _showImageSourceBottomSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final int previewCacheWidth = (280.w * devicePixelRatio).round();
    final int previewCacheHeight = (320.h * devicePixelRatio).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
          child: Obx(
            () => SingleChildScrollView(
              padding: EdgeInsets.only(
                top: AppSpacing.lg.h,
                bottom: AppSpacing.xxl.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ScreenHeader(
                    title: 'Upload Receipt',
                    subtitle:
                        'Add your receipt to extract and save shopping details',
                    showBackButton: false,
                  ),
                  SizedBox(height: AppSpacing.lg.h),
                  SectionCard(
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
                                    'Current Location',
                                    style: AppTextStyles.titleLarge.copyWith(
                                      fontSize: 18.sp,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Confirm your location before uploading the receipt',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.md.h),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: VoiceActionChip(
                            label: controller.isFetchingLocation.value
                                ? 'Getting location...'
                                : controller.latitude.value != null &&
                                          controller.longitude.value != null
                                    ? 'Current location enabled'
                                    : 'Use Current Location',
                            icon: controller.isFetchingLocation.value
                                ? Icons.hourglass_top_rounded
                                : controller.latitude.value != null &&
                                          controller.longitude.value != null
                                    ? Icons.my_location_rounded
                                    : Icons.location_searching_rounded,
                            isActive: controller.latitude.value != null &&
                                controller.longitude.value != null,
                            onTap: controller.isFetchingLocation.value
                                ? () {}
                                : controller.getCurrentLocation,
                          ),
                        ),
                        SizedBox(height: AppSpacing.md.h),
                        CustomTextField(
                          controller: controller.postcodeController,
                          labelText: 'Postcode',
                          hintText: 'Postcode will appear here',
                          readOnly: false,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: controller.onPostcodeChanged,
                          prefixIcon: Icon(
                            Icons.place_outlined,
                            size: 20.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        CustomTextField(
                          controller: controller.latitudeController,
                          labelText: 'Latitude',
                          hintText: 'Latitude will appear here',
                          readOnly: true,
                          prefixIcon: Icon(
                            Icons.explore_outlined,
                            size: 20.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        CustomTextField(
                          controller: controller.longitudeController,
                          labelText: 'Longitude',
                          hintText: 'Longitude will appear here',
                          readOnly: true,
                          prefixIcon: Icon(
                            Icons.near_me_outlined,
                            size: 20.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg.h),
                  SectionCard(
                    padding: EdgeInsets.all(AppSpacing.lg.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receipt Image',
                                style: AppTextStyles.titleLarge.copyWith(
                                  fontSize: 18.sp,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Select a clear receipt photo for the best extraction result',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontSize: 13.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: AppSpacing.md.h),
                        GestureDetector(
                          onTap: () => _handleReceiptSourceTap(context),
                          child: Container(
                            width: double.infinity,
                            height: 320.h,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1.3,
                              ),
                              boxShadow: AppDecorations.card.boxShadow,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: controller.isProcessing.value
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        color: AppColors.primaryDark,
                                      ),
                                      SizedBox(height: 16.h),
                                      Text(
                                        'Scanning receipt...',
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          fontSize: 16.sp,
                                        ),
                                      ),
                                    ],
                                  )
                                : controller.selectedImage.value != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.file(
                                            File(
                                              controller.selectedImage.value!.path,
                                            ),
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.low,
                                            cacheWidth: previewCacheWidth,
                                            cacheHeight: previewCacheHeight,
                                          ),
                                          Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 16.w,
                                                vertical: 12.h,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.black.withOpacity(0.0),
                                                    Colors.black.withOpacity(0.55),
                                                  ],
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    color: Colors.white,
                                                    size: 18.sp,
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  Expanded(
                                                    child: Text(
                                                      'Receipt image selected. Tap to choose another one.',
                                                      style: AppTextStyles.bodyMedium.copyWith(
                                                        fontSize: 13.sp,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(20.r),
                                        ),
                                        child: Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 28.w,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 78.w,
                                                  height: 78.h,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryLight,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.receipt_long_outlined,
                                                    size: 38.sp,
                                                    color: AppColors.primaryDark,
                                                  ),
                                                ),
                                                SizedBox(height: 18.h),
                                                Text(
                                                  'Tap to select receipt image',
                                                  textAlign: TextAlign.center,
                                                  style: AppTextStyles.titleLarge
                                                      .copyWith(fontSize: 20.sp),
                                                ),
                                                SizedBox(height: 8.h),
                                                Text(
                                                  'Choose a clear receipt photo for better extraction',
                                                  textAlign: TextAlign.center,
                                                  style: AppTextStyles.bodyMedium
                                                      .copyWith(fontSize: 13.sp),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg.h),
                  PrimaryButton(
                    text: 'Upload Receipt',
                    textColor: Colors.white,
                    height: 56,
                    icon: Icons.cloud_upload_outlined,
                    onPressed: () => _handleReceiptSourceTap(context),
                  ),
                  if (controller.hasConfirmedReceipt.value) ...[
                    SizedBox(height: AppSpacing.xl.h),
                    SectionCard(
                      padding: EdgeInsets.all(AppSpacing.lg.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (controller.parsedReceipt.value?.storeName != null) ...[
                            Text(
                              'Store: ${controller.parsedReceipt.value!.storeName}',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontSize: 16.sp,
                              ),
                            ),
                            SizedBox(height: 12.h),
                          ],
                          Text(
                            'Extracted Receipt Summary',
                            style: AppTextStyles.titleLarge.copyWith(
                              fontSize: 18.sp,
                            ),
                          ),
                          SizedBox(height: 14.h),
                          ...controller.extractedItems.map(
                            (item) => Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: Row(
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
                                      borderRadius: BorderRadius.circular(999.r),
                                    ),
                                    child: Text(
                                      item.price != null
                                          ? '£${item.price!.toStringAsFixed(2)}'
                                          : '-',
                                      style: AppTextStyles.titleMedium.copyWith(
                                        fontSize: 13.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (controller.parsedReceipt.value?.subtotal != null) ...[
                            SizedBox(height: 6.h),
                            Text(
                              'Subtotal: £${controller.parsedReceipt.value!.subtotal!.toStringAsFixed(2)}',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                          if (controller.parsedReceipt.value?.tax != null) ...[
                            SizedBox(height: 6.h),
                            Text(
                              'Tax: £${controller.parsedReceipt.value!.tax!.toStringAsFixed(2)}',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                          if (controller.parsedReceipt.value?.total != null) ...[
                            SizedBox(height: 6.h),
                            Text(
                              'Total: £${controller.parsedReceipt.value!.total!.toStringAsFixed(2)}',
                              style: AppTextStyles.titleLarge.copyWith(
                                fontSize: 15.sp,
                              ),
                            ),
                          ],
                          SizedBox(height: AppSpacing.md.h),
                          Text(
                            'Recognized Text',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontSize: 16.sp,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            child: Text(
                              controller.recognizedText.value,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 13.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showImageSourceBottomSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Container(
            padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 28.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20.r,
                  offset: Offset(0, -4.h),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                ),
                SizedBox(height: 18.h),
                const CustomText(
                  'Select Image Source',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: _BottomSheetActionCard(
                        icon: Icons.camera_alt_outlined,
                        label: 'Camera',
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          controller.pickFromCamera();
                        },
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: _BottomSheetActionCard(
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          controller.pickFromGallery();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BottomSheetActionCard extends StatelessWidget {
  const _BottomSheetActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Ink(
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F4EF),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.splashBackground),
          ),
          child: Column(
            children: [
              Container(
                width: 58.w,
                height: 58.h,
                decoration: BoxDecoration(
                  color: AppColors.splashBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28.sp, color: Colors.white),
              ),
              SizedBox(height: 12.h),
              CustomText(label, fontSize: 15, fontWeight: FontWeight.w700),
            ],
          ),
        ),
      ),
    );
  }
}
