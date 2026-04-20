library;

class AppGridTheme {
  /// Standard calculation for the number of columns based on screen width
  static int getCrossAxisCount(double width) {
    return 3;
  }

  /// Standard aspect ratio for media grid items (width / height)
  /// An aspect ratio of ~0.70-0.75 allows for a square cover + text below.
  static const double childAspectRatio = 0.655;

  /// Standard spacing between grid items
  static const double spacing = 14.0;
}
