/// Utility class for UI helper functions
class UIHelpers {
  /// Clamps opacity value between 0.0 and 1.0
  static double clampOpacity(double value) {
    return value.clamp(0.0, 1.0);
  }
}
