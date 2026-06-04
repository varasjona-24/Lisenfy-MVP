import 'capture_item.dart';

class CaptureTagFolder {
  const CaptureTagFolder({
    required this.key,
    required this.tag,
    required this.colorValue,
    required this.captures,
    this.thumbnailPath,
  });

  final String key;
  final String tag;
  final int colorValue;
  final List<CaptureItem> captures;
  final String? thumbnailPath;

  int get count => captures.length;
}
