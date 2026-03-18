import 'StoreTotalModel.dart';

class RecommendationResultModel {
  const RecommendationResultModel({
    this.cheapestStore,
    this.secondBestStore,
    required this.savingsAmount,
  });

  final StoreTotalModel? cheapestStore;
  final StoreTotalModel? secondBestStore;
  final double savingsAmount;
}
