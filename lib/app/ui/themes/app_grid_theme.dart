library;

class AppGridTheme {
  /// Standard calculation for the number of columns based on screen width
  static int getCrossAxisCount(double width) {
    if (width >= 1900) return 8;
    if (width >= 1600) return 7;
    if (width >= 1320) return 6;
    if (width >= 1060) return 5;
    if (width >= 820) return 4;
    if (width >= 520) return 3;
    return 2;
  }

  static int getVideoCrossAxisCount(double width) {
    if (width >= 1800) return 4;
    if (width >= 1200) return 3;
    if (width >= 680) return 2;
    return 1;
  }

  static int getCollectionCrossAxisCount(double width) {
    if (width >= 1500) return 5;
    if (width >= 1120) return 4;
    if (width >= 760) return 3;
    if (width >= 460) return 2;
    return 1;
  }

  /// Standard aspect ratio for media grid items (width / height)
  /// An aspect ratio of ~0.70-0.75 allows for a square cover + text below.
  static const double childAspectRatio = 0.655;
  static const double videoChildAspectRatio = 1.34;

  /// Standard spacing between grid items
  static const double spacing = 14.0;
}
