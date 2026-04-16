class PostcodeValidator {
  const PostcodeValidator._();

  static final RegExp _ukPostcodeRegExp = RegExp(
    r'^(GIR 0AA|[A-PR-UWYZ][A-HK-Y]?\d[A-Z\d]? ?\d[ABD-HJLNP-UW-Z]{2})$',
    caseSensitive: false,
  );

  static String normalize(String? value) {
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

  static bool isValid(String? value) {
    final String normalizedPostcode = normalize(value);

    if (normalizedPostcode.isEmpty) {
      return false;
    }

    return _ukPostcodeRegExp.hasMatch(normalizedPostcode);
  }

  static String? validate(String? value) {
    final String normalizedPostcode = normalize(value);

    if (normalizedPostcode.isEmpty) {
      return 'Postcode is required';
    }

    if (!_ukPostcodeRegExp.hasMatch(normalizedPostcode)) {
      return 'Enter a valid UK postcode';
    }

    return null;
  }
}
