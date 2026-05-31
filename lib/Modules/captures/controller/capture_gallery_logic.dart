import '../domain/capture_gallery_models.dart';

class CaptureGalleryLogic {
  const CaptureGalleryLogic();

  List<CaptureItem> filterAndSort({
    required Iterable<CaptureItem> captures,
    required String query,
    required CaptureSort sort,
    required bool ascending,
  }) {
    final text = query.trim().toLowerCase();
    final filtered = text.isEmpty
        ? captures
        : captures.where((capture) {
            return capture.name.toLowerCase().contains(text) ||
                capture.tags.any((tag) => tag.toLowerCase().contains(text));
          });

    final sorted = List<CaptureItem>.from(filtered);
    switch (sort) {
      case CaptureSort.date:
        sorted.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
      case CaptureSort.size:
        sorted.sort((a, b) => a.size.compareTo(b.size));
      case CaptureSort.name:
        sorted.sort((a, b) => a.name.compareTo(b.name));
    }
    return ascending ? sorted : sorted.reversed.toList();
  }

  String directionLabel({
    required CaptureSort option,
    required CaptureSort current,
    required bool ascending,
  }) {
    if (option != current) {
      return switch (option) {
        CaptureSort.date => 'Más reciente primero',
        CaptureSort.size => 'Mayor a menor',
        CaptureSort.name => 'A-Z',
      };
    }
    return switch (option) {
      CaptureSort.date =>
        ascending ? 'Más antiguo primero' : 'Más reciente primero',
      CaptureSort.size => ascending ? 'Menor a mayor' : 'Mayor a menor',
      CaptureSort.name => ascending ? 'A-Z' : 'Z-A',
    };
  }
}
