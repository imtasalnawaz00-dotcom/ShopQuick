import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../my_receipts/controller/MyReceiptsController.dart';
import '../../../helper/AppSnackbar.dart';
import '../../../services/CurrentLocationService.dart';
import '../../../services/DatabaseService.dart';
import '../../../services/ReceiptParserService.dart';
import '../../../widgets/CustomText.dart';
import '../../../widgets/PrimaryButton.dart';
import '../../../services/ReceiptUploadService.dart';
import '../model/ParsedReceiptItemModel.dart';
import '../model/ParsedReceiptModel.dart';
import '../model/ReceiptItemModel.dart';

class ReceiptUploadController extends GetxController {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController postcodeController = TextEditingController();
  final TextEditingController latitudeController = TextEditingController();
  final TextEditingController longitudeController = TextEditingController();
  final Rxn<File> selectedImage = Rxn<File>();
  final RxBool isProcessing = false.obs;
  final RxBool isFetchingLocation = false.obs;
  final RxBool isLocationServiceEnabled = true.obs;
  final RxString recognizedText = ''.obs;
  final RxList<ReceiptItemModel> extractedItems = <ReceiptItemModel>[].obs;
  final Rxn<ParsedReceiptModel> parsedReceipt = Rxn<ParsedReceiptModel>();
  final RxBool hasConfirmedReceipt = false.obs;
  final RxString postcode = ''.obs;
  final RxnDouble latitude = RxnDouble();
  final RxnDouble longitude = RxnDouble();
  final CurrentLocationService _currentLocationService =
      const CurrentLocationService();
  final DatabaseService _databaseService = DatabaseService.instance;
  final ReceiptParserService _receiptParserService = const ReceiptParserService();
  final ReceiptUploadService _receiptUploadService =
      const ReceiptUploadService();

  @override
  void onInit() {
    super.onInit();
    refreshLocationServiceState();
  }

  Future<void> pickFromCamera() async {
    await _pickImage(ImageSource.camera);
  }

  Future<void> pickFromGallery() async {
    await _pickImage(ImageSource.gallery);
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
    );

    if (pickedFile == null) {
      return;
    }

    selectedImage.value = File(pickedFile.path);
    hasConfirmedReceipt.value = false;
    await processSelectedImage();
  }

  Future<void> getCurrentLocation() async {
    if (isFetchingLocation.value) {
      return;
    }

    isFetchingLocation.value = true;

    try {
      final bool serviceEnabled = await refreshLocationServiceState();

      if (!serviceEnabled) {
        CustomErrorSnackbar.showError(
          title: 'Location',
          message: 'Please enable device location services and try again.',
        );
        await Geolocator.openLocationSettings();
        return;
      }

      final bool permissionGranted = await _currentLocationService
          .ensurePermissionGranted();

      if (!permissionGranted) {
        CustomErrorSnackbar.showError(
          title: 'Location',
          message: 'Location permission is required to continue.',
        );
        return;
      }

      final CurrentLocationResult locationResult =
          await _currentLocationService.fetchCurrentLocation();

      latitude.value = locationResult.latitude;
      longitude.value = locationResult.longitude;
      postcode.value = locationResult.postcode;
      postcodeController.text = locationResult.postcode;
      latitudeController.text = locationResult.latitude.toStringAsFixed(6);
      longitudeController.text = locationResult.longitude.toStringAsFixed(6);

      if (locationResult.postcode.isEmpty) {
        CustomErrorSnackbar.showError(
          title: 'Location',
          message:
              'Current location fetched, but no postcode was returned for this address.',
        );
      } else {
        CustomSuccessSnackbar.showSuccess(
          title: 'Location',
          message: 'Current location fetched successfully.',
        );
      }
    } catch (_) {
      CustomErrorSnackbar.showError(
        title: 'Location',
        message: 'Unable to fetch current location right now.',
      );
    } finally {
      isFetchingLocation.value = false;
    }
  }

  Future<bool> refreshLocationServiceState() async {
    final bool serviceEnabled = await _currentLocationService
        .isLocationServiceEnabled();
    isLocationServiceEnabled.value = serviceEnabled;
    return serviceEnabled;
  }

  Future<bool> validateLocationBeforeReceiptUpload() async {
    final bool serviceEnabled = await refreshLocationServiceState();

    if (!serviceEnabled) {
      CustomErrorSnackbar.showError(
        title: 'Location Required',
        message: 'Please enable device location services before uploading a receipt.',
      );
      return false;
    }

    final bool permissionGranted = await _currentLocationService
        .ensurePermissionGranted();

    if (!permissionGranted) {
      CustomErrorSnackbar.showError(
        title: 'Location Required',
        message: 'Please allow location permission before uploading a receipt.',
      );
      return false;
    }

    if (postcodeController.text.trim().isEmpty) {
      CustomErrorSnackbar.showError(
        title: 'Postcode Required',
        message: 'Please add the postcode to proceed.',
      );
      return false;
    }

    if (latitudeController.text.trim().isEmpty ||
        longitudeController.text.trim().isEmpty ||
        latitude.value == null ||
        longitude.value == null) {
      CustomErrorSnackbar.showError(
        title: 'Location Required',
        message: 'Please fetch your current latitude and longitude before continuing.',
      );
      return false;
    }

    return true;
  }

  void onPostcodeChanged(String value) {
    postcode.value = value.trim().toUpperCase();
  }

  Future<void> processSelectedImage() async {
    final File? imageFile = selectedImage.value;

    if (imageFile == null) {
      return;
    }

    isProcessing.value = true;
    recognizedText.value = '';
    extractedItems.clear();
    parsedReceipt.value = null;

    try {
      // Parse the scanned text into item rows before showing the preview.
      final String text = await scanReceiptText(imageFile);
      recognizedText.value = text.trim();

      if (recognizedText.value.isEmpty) {
        CustomErrorSnackbar.showError(
          title: 'Receipt Scan',
          message: 'No receipt text was detected.',
        );
        return;
      }

      final ParsedReceiptModel parsedResult = _receiptParserService.parse(
        recognizedText.value,
      );
      parsedReceipt.value = parsedResult;
      extractedItems.assignAll(
        parsedResult.items
            .map(
              (ParsedReceiptItemModel item) => ReceiptItemModel(
                itemName: item.itemName,
                price: item.price,
              ),
            )
            .toList(),
      );

      if (parsedResult.items.isEmpty) {
        CustomErrorSnackbar.showError(
          title: 'Receipt Scan',
          message: 'Receipt text was found, but no item-price pairs could be parsed.',
        );
      }

      showReceiptPreviewDialog();
    } catch (_) {
      CustomErrorSnackbar.showError(
        title: 'Receipt Scan',
        message: 'Failed to scan receipt text.',
      );
    } finally {
      isProcessing.value = false;
    }
  }

  Future<String> scanReceiptText(File imageFile) async {
    final InputImage inputImage = InputImage.fromFile(imageFile);
    final TextRecognizer textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final RecognizedText recognizedResult = await textRecognizer.processImage(
        inputImage,
      );
      return recognizedResult.text;
    } finally {
      textRecognizer.close();
    }
  }

  void showReceiptPreviewDialog() {
    final ParsedReceiptModel? parsed = parsedReceipt.value;

    Get.dialog(
      Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 32.h,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Center(
                      child: CustomText(
                        'Scanned Receipt',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Material(
                        color: AppColors.primaryButton,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: Get.back,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 32.w,
                            height: 32.h,
                            child: Icon(
                              Icons.close_rounded,
                              size: 20.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              if (selectedImage.value != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: Image.file(
                    selectedImage.value!,
                    height: 120.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    cacheWidth: 900,
                    cacheHeight: 450,
                  ),
                ),
              SizedBox(height: 16.h),
              SizedBox(
                height: 260.h,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (parsed?.storeName != null) ...[
                        CustomText(
                          'Store: ${parsed!.storeName}',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        SizedBox(height: 12.h),
                      ],
                      const CustomText(
                        'Extracted Items',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      SizedBox(height: 10.h),
                      ...extractedItems.map(
                        (ReceiptItemModel item) => Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: Row(
                            children: [
                              Expanded(
                                child: CustomText(item.itemName, fontSize: 14),
                              ),
                              CustomText(
                                item.price != null
                                    ? '£${item.price!.toStringAsFixed(2)}'
                                    : '-',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (parsed?.subtotal != null) ...[
                        SizedBox(height: 12.h),
                        CustomText(
                          'Subtotal: £${parsed!.subtotal!.toStringAsFixed(2)}',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ],
                      if (parsed?.tax != null) ...[
                        SizedBox(height: 6.h),
                        CustomText(
                          'Tax: £${parsed!.tax!.toStringAsFixed(2)}',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ],
                      if (parsed?.total != null) ...[
                        SizedBox(height: 6.h),
                        CustomText(
                          'Total: £${parsed!.total!.toStringAsFixed(2)}',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ],
                      SizedBox(height: 12.h),
                      const CustomText(
                        'Raw Text',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F4EF),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: CustomText(
                          recognizedText.value,
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              PrimaryButton(
                text: 'Upload Done',
                textColor: Colors.white,
                onPressed: confirmAndUploadReceipt,
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> confirmAndUploadReceipt() async {
    final File? imageFile = selectedImage.value;
    final List<ReceiptItemModel> extractedReceiptItems = extractedItems.toList();
    final ParsedReceiptModel? parsed = parsedReceipt.value;

    // Save the parsed receipt for this user and refresh the history tab.
    final ReceiptSaveResult saveResult = await _databaseService.saveReceiptItems(
      items: extractedReceiptItems,
      userKey: 'user_1',
      rawText: recognizedText.value,
      imagePath: imageFile?.path,
      storeName: parsed?.storeName,
      postcode: postcodeController.text.trim().toUpperCase(),
      latitude: latitude.value,
      longitude: longitude.value,
    );

    await _receiptUploadService.uploadReceiptData(
      items: extractedReceiptItems,
      rawText: recognizedText.value,
      image: imageFile,
    );

    if (Get.isRegistered<MyReceiptsController>()) {
      await Get.find<MyReceiptsController>().loadReceipts();
    }

    hasConfirmedReceipt.value = true;
    Get.back();
    CustomSuccessSnackbar.showSuccess(
      title: 'Receipt Upload',
      message:
          'Receipt data saved successfully. Receipt #${saveResult.receiptId} with ${saveResult.insertedRows} items.',
    );
  }

  @override
  void onClose() {
    postcodeController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.onClose();
  }
}
