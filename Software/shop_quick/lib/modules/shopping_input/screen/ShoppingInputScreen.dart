import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../helper/AppSnackbar.dart';
import '../../../widgets/CustomText.dart';
import '../../../widgets/CustomTextField.dart';
import '../../../widgets/info_mini_card.dart';
import '../../../widgets/PrimaryButton.dart';
import '../../../widgets/screen_header.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/voice_action_chip.dart';
import '../controller/ShoppingInputController.dart';

class ShoppingInputScreen extends GetView<ShoppingInputController> {
  const ShoppingInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ColoredBox(
        color: AppColors.background,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg.w,
              AppSpacing.lg.h,
              AppSpacing.lg.w,
              AppSpacing.xl.h,
            ),
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const ScreenHeader(
                  title: 'Plan Grocery Basket',
                  subtitle: 'Find the cheapest store near you',
                ),
                SizedBox(height: AppSpacing.lg.h),
                SectionCard(
                  title: 'Location',
                  subtitle: 'Add your postcode or use your current location',
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: controller.postcodeController,
                        labelText: 'Postcode',
                        hintText: 'e.g. BD7 1DP',
                        prefixIcon: Icon(
                          Icons.location_on_outlined,
                          size: 20.sp,
                          color: AppColors.textSecondary,
                        ),
                        maxLength: 8,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9 ]'),
                          ),
                          UpperCaseTextFormatter(),
                        ],
                        validator: controller.validatePostcode,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).unfocus(),
                      ),
                      SizedBox(height: AppSpacing.md.h),
                      Obx(
                        () => Align(
                          alignment: Alignment.centerLeft,
                          child: VoiceActionChip(
                            label: controller.isFetchingLocation.value
                                ? 'Getting location...'
                                : controller.useCurrentLocation.value
                                    ? 'Current location enabled'
                                    : 'Use Current Location',
                            icon: controller.isFetchingLocation.value
                                ? Icons.hourglass_top_rounded
                                : controller.useCurrentLocation.value
                                    ? Icons.my_location_rounded
                                    : Icons.location_searching_rounded,
                            isActive: controller.useCurrentLocation.value,
                            onTap: controller.isFetchingLocation.value
                                ? () {}
                                : controller.onUseCurrentLocationTap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),
                Obx(
                  () {
                    final double? latitude = controller.latitude.value;
                    final double? longitude = controller.longitude.value;

                    return Row(
                      children: [
                        Expanded(
                          child: _CopyableInfoMiniCard(
                            title: 'Latitude',
                            value: latitude != null
                                ? latitude.toStringAsFixed(5)
                                : 'Latitude will appear here',
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm.w),
                        Expanded(
                          child: _CopyableInfoMiniCard(
                            title: 'Longitude',
                            value: longitude != null
                                ? longitude.toStringAsFixed(5)
                                : 'Longitude will appear here',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: AppSpacing.sm.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: CustomText(
                    'Results will be shown for stores within ${controller.searchRadius.toStringAsFixed(0)} miles',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),
                SectionCard(
                  title: 'Shopping List',
                  subtitle: '',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Obx(
                              () => CustomText(
                                controller.speechStatus.value,
                                fontSize: controller.isListening.value ? 13 : 12,
                                color: controller.isListening.value
                                    ? Colors.redAccent
                                    : AppColors.textSecondary,
                                fontWeight: controller.isListening.value
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm.w),
                          Obx(
                            () => VoiceActionChip(
                              label: controller.isListening.value
                                  ? 'Listening'
                                  : 'Speak Items',
                              icon: controller.isListening.value
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                              isActive: controller.isListening.value,
                              onTap: controller.toggleListening,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.md.h),
                      CustomTextField(
                        controller: controller.shoppingItemsController,
                        labelText: 'Shopping Items',
                        hintText: 'Type items separated by commas',
                        maxLines: 5,
                        minLines: 4,
                        textInputAction: TextInputAction.done,
                        onEditingComplete: () {
                          controller.addShoppingItemsFromInput();
                          FocusScope.of(context).unfocus();
                        },
                        onFieldSubmitted: (_) {
                          controller.addShoppingItemsFromInput();
                        },
                        validator: controller.validateShoppingItems,
                      ),
                      SizedBox(height: AppSpacing.md.h),
                      Obx(
                        () => Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: controller.shoppingItems
                              .map(
                                (String item) => Chip(
                                  label: CustomText(
                                    item,
                                    fontSize: 14,
                                  ),
                                  deleteIcon: Icon(
                                    Icons.close,
                                    size: 16.sp,
                                  ),
                                  onDeleted: () =>
                                      controller.removeShoppingItem(item),
                                  backgroundColor: AppColors.primaryLight,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24.r),
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),
                SectionCard(
                  title: 'Budget',
                  child: CustomTextField(
                    controller: controller.budgetController,
                    labelText: 'Budget',
                    hintText: 'e.g. £40',
                    prefixIcon: Icon(
                      Icons.currency_pound_rounded,
                      size: 20.sp,
                      color: AppColors.textSecondary,
                    ),
                    maxLength: 7,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).unfocus(),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    validator: controller.validateBudget,
                  ),
                ),
                SizedBox(height: AppSpacing.xl.h),
                PrimaryButton(
                  text: 'Get Cheapest Store',
                  textColor: Colors.white,
                  icon: Icons.shopping_basket_rounded,
                  onPressed: controller.submitShoppingRequest,
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CopyableInfoMiniCard extends StatelessWidget {
  const _CopyableInfoMiniCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: value));
        CustomSuccessSnackbar.showSuccess(
          title: 'Copied',
          message: '$title copied',
        );
      },
      child: InfoMiniCard(
        label: title,
        value: value,
        icon: title == 'Latitude'
            ? Icons.explore_outlined
            : Icons.place_outlined,
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
