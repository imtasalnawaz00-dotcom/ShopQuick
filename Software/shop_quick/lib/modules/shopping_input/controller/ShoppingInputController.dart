import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../constants/Routes.dart';
import '../../../helper/AppSnackbar.dart';
import '../../recommendations/controller/RecommendationController.dart';
import '../model/ShoppingRequestModel.dart';

class ShoppingInputController extends GetxController {
  static final RegExp _ukPostcodeRegExp = RegExp(
    r'^(GIR 0AA|[A-PR-UWYZ][A-HK-Y]?\d[A-Z\d]? ?\d[ABD-HJLNP-UW-Z]{2})$',
    caseSensitive: false,
  );

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController postcodeController = TextEditingController();
  final TextEditingController budgetController = TextEditingController();
  final TextEditingController shoppingItemsController = TextEditingController();
  final RxList<String> shoppingItems = <String>[].obs;
  final RxBool useCurrentLocation = false.obs;
  final RxBool isFetchingLocation = false.obs;
  final RxBool isListening = false.obs;
  final RxBool isSpeechAvailable = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxnDouble latitude = RxnDouble();
  final RxnDouble longitude = RxnDouble();
  final RxString recognizedText = ''.obs;
  final RxString speechStatus = 'Tap the microphone to speak'.obs;
  String selectedPostcode = '';
  final double searchRadius = 3.0;
  final SpeechToText _speechToText = SpeechToText();
  bool _speechInitialized = false;

  ShoppingRequestModel? shoppingRequest;

  @override
  void onInit() {
    super.onInit();
    initSpeech();
  }

  String? validatePostcode(String? value) {
    final String normalizedPostcode = _normalizePostcode(value);

    if (normalizedPostcode.isEmpty) {
      return 'Postcode is required';
    }

    if (!_ukPostcodeRegExp.hasMatch(normalizedPostcode)) {
      return 'Enter a valid UK postcode';
    }

    return null;
  }

  String? validateBudget(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Budget is required';
    }
    return null;
  }

  void addShoppingItemsFromInput() {
    _syncShoppingItemsFromText(shoppingItemsController.text, clearInput: true);
  }

  void removeShoppingItem(String item) {
    shoppingItems.remove(item);
  }

  Future<void> initSpeech() async {
    if (_speechInitialized) {
      return;
    }

    try {
      isSpeechAvailable.value = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: false,
      );
      _speechInitialized = true;
      speechStatus.value = isSpeechAvailable.value
          ? 'Tap the microphone to speak'
          : 'Speech recognition unavailable';
    } catch (_) {
      isSpeechAvailable.value = false;
      speechStatus.value = 'Speech recognition unavailable';
    }
  }

  Future<void> startListening() async {
    if (!_speechInitialized || !isSpeechAvailable.value) {
      await initSpeech();
    }

    if (!isSpeechAvailable.value) {
      CustomErrorSnackbar.showError(
        title: 'Voice Input',
        message: 'Microphone permission or speech recognition is unavailable.',
      );
      return;
    }

    if (_speechToText.isListening) {
      return;
    }

    recognizedText.value = shoppingItemsController.text;
    isListening.value = true;
    speechStatus.value = 'Listening...';

    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenMode: ListenMode.confirmation,
      partialResults: true,
    );
  }

  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    isListening.value = false;
    speechStatus.value = 'Tap the microphone to speak';

    if (recognizedText.value.trim().isNotEmpty) {
      shoppingItemsController.text = recognizedText.value.trim();
      _syncShoppingItemsFromText(recognizedText.value, clearInput: false);
    }
  }

  Future<void> toggleListening() async {
    if (isListening.value) {
      await stopListening();
      return;
    }

    await startListening();
  }

  Future<void> onUseCurrentLocationTap() async {
    if (isFetchingLocation.value) {
      return;
    }

    isFetchingLocation.value = true;

    try {
      final bool serviceEnabled = await checkLocationService();

      if (!serviceEnabled) {
        return;
      }

      final bool permissionGranted = await requestLocationPermission();

      if (!permissionGranted) {
        return;
      }

      await getCurrentLocation();
    } catch (_) {
      CustomErrorSnackbar.showError(
        title: 'Location',
        message: 'Unable to fetch current location right now.',
      );
    } finally {
      isFetchingLocation.value = false;
    }
  }

  Future<bool> checkLocationService() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      CustomErrorSnackbar.showError(
        title: 'Location',
        message: 'Please enable device location services and try again.',
      );
      await Geolocator.openLocationSettings();
    }

    return serviceEnabled;
  }

  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      CustomErrorSnackbar.showError(
        title: 'Location',
        message: 'Location permission was denied.',
      );
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      CustomErrorSnackbar.showError(
        title: 'Location',
        message:
            'Location permission is permanently denied. Please enable it from settings.',
      );
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  Future<void> getCurrentLocation() async {
    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    latitude.value = position.latitude;
    longitude.value = position.longitude;
    useCurrentLocation.value = true;
    if (postcodeController.text.trim().isNotEmpty) {
      selectedPostcode = postcodeController.text.trim();
    } else {
      selectedPostcode = '';
    }

    CustomSuccessSnackbar.showSuccess(
      title: 'Location',
      message: 'Current location fetched successfully.',
    );
  }

  String? validateShoppingItems(String? value) {
    if (shoppingItems.isEmpty && (value == null || value.trim().isEmpty)) {
      return 'Shopping items are required';
    }
    return null;
  }

  void submitShoppingRequest() {
    if (isSubmitting.value) {
      return;
    }

    addShoppingItemsFromInput();

    final FormState? formState = formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    if (latitude.value == null || longitude.value == null) {
      CustomErrorSnackbar.showError(
        title: 'Location Required',
        message: 'Current location is required before processing.',
      );
      return;
    }

    selectedPostcode = _normalizePostcode(postcodeController.text);

    shoppingRequest = ShoppingRequestModel(
      postcode: selectedPostcode,
      budget: budgetController.text.trim(),
      shoppingItems: shoppingItems.join(', '),
      userLatitude: latitude.value,
      userLongitude: longitude.value,
    );

    // Open the recommendation screen with the latest manual input.
    isSubmitting.value = true;

    if (Get.isRegistered<RecommendationController>()) {
      Get.delete<RecommendationController>(force: true);
    }

    Get.toNamed(
      Routes.recommendations,
      arguments: shoppingRequest,
    )?.whenComplete(() {
      isSubmitting.value = false;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    recognizedText.value = result.recognizedWords;
    shoppingItemsController.text = result.recognizedWords;
    shoppingItemsController.selection = TextSelection.fromPosition(
      TextPosition(offset: shoppingItemsController.text.length),
    );

    if (result.finalResult) {
      _syncShoppingItemsFromText(result.recognizedWords, clearInput: false);
      stopListening();
    }
  }

  void _onSpeechStatus(String status) {
    if (status == 'listening') {
      isListening.value = true;
      speechStatus.value = 'Listening...';
      return;
    }

    if (status == 'done' || status == 'notListening') {
      if (isListening.value) {
        stopListening();
      } else {
        speechStatus.value = 'Tap the microphone to speak';
      }
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    isListening.value = false;
    speechStatus.value = 'Speech recognition unavailable';

    CustomErrorSnackbar.showError(
      title: 'Voice Input',
      message: 'Speech recognition failed: ${error.errorMsg}',
    );
  }

  void _syncShoppingItemsFromText(String value, {required bool clearInput}) {
    final List<String> parsedItems = value
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();

    // Keep the spoken and typed items merged into one list.
    for (final String item in parsedItems) {
      if (!shoppingItems.contains(item)) {
        shoppingItems.add(item);
      }
    }

    if (clearInput) {
      shoppingItemsController.clear();
      recognizedText.value = '';
    }
  }

  String _normalizePostcode(String? value) {
    return value
            ?.trim()
            .toUpperCase()
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAllMapped(
              RegExp(r'^([A-Z]{1,2}\d[A-Z\d]?)(\d[ABD-HJLNP-UW-Z]{2})$'),
              (Match match) => '${match.group(1)} ${match.group(2)}',
            ) ??
        '';
  }

  @override
  void onClose() {
    _speechToText.stop();
    postcodeController.dispose();
    budgetController.dispose();
    shoppingItemsController.dispose();
    super.onClose();
  }
}
