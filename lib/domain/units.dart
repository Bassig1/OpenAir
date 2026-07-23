/// Display helpers. Storage stays metric (kg / cm) internally.
class Units {
  const Units._();

  static const kgToLb = 2.2046226218;
  static const cmToIn = 1 / 2.54;

  static String weight(double? kg, {required bool metric, int decimals = 1}) {
    if (kg == null) return '—';
    if (metric) return '${kg.toStringAsFixed(decimals)} kg';
    return '${(kg * kgToLb).toStringAsFixed(decimals)} lb';
  }

  static String height(double? cm, {required bool metric, int decimals = 1}) {
    if (cm == null) return '—';
    if (metric) return '${cm.toStringAsFixed(0)} cm';
    return '${(cm * cmToIn).toStringAsFixed(decimals)} in';
  }

  static String distanceMeters(double? meters, {required bool metric}) {
    if (meters == null) return '—';
    if (metric) {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(km >= 10 ? 1 : 2)} km';
    }
    final mi = meters / 1609.344;
    return '${mi.toStringAsFixed(mi >= 10 ? 1 : 2)} mi';
  }

  static double? lbToKg(double? lb) => lb == null ? null : lb / kgToLb;
  static double? inToCm(double? inches) =>
      inches == null ? null : inches / cmToIn;
  static double? kgToLbValue(double? kg) =>
      kg == null ? null : kg * kgToLb;
  static double? cmToInValue(double? cm) =>
      cm == null ? null : cm * cmToIn;
}
