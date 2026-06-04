import 'capture_item.dart';

class CaptureTagFolder {
  const CaptureTagFolder({
    required this.tag,
    required this.colorValue,
    required this.captures,
  });

  final String tag;
  final int colorValue;
  final List<CaptureItem> captures;

  int get count => captures.length;
}
