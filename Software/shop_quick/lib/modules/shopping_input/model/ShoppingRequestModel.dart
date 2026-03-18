class ShoppingRequestModel {
  const ShoppingRequestModel({
    required this.postcode,
    required this.budget,
    required this.shoppingItems,
    this.userLatitude,
    this.userLongitude,
  });

  final String postcode;
  final String budget;
  final String shoppingItems;
  final double? userLatitude;
  final double? userLongitude;

  ShoppingRequestModel copyWith({
    String? postcode,
    String? budget,
    String? shoppingItems,
    double? userLatitude,
    double? userLongitude,
  }) {
    return ShoppingRequestModel(
      postcode: postcode ?? this.postcode,
      budget: budget ?? this.budget,
      shoppingItems: shoppingItems ?? this.shoppingItems,
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
    );
  }
}
