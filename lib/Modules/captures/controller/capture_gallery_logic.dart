import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;

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
        CaptureSort.date => tr('captures.sort.newest_first'),
        CaptureSort.size => tr('home.section.high_to_low'),
        CaptureSort.name => 'A-Z',
      };
    }
    return switch (option) {
      CaptureSort.date =>
        ascending
            ? tr('captures.sort.oldest_first')
            : tr('captures.sort.newest_first'),
      CaptureSort.size =>
        ascending
            ? tr('home.section.low_to_high')
            : tr('home.section.high_to_low'),
      CaptureSort.name => ascending ? 'A-Z' : 'Z-A',
    };
  }
}
