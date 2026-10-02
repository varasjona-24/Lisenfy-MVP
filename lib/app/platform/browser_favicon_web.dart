import 'dart:js_interop';

@JS('listenfySetFaviconColor')
external void _setBrowserFaviconColor(JSString color);

void updateBrowserFaviconColor(int argb) {
  final rgb = argb & 0x00ffffff;
  final hex = '#${rgb.toRadixString(16).padLeft(6, '0')}';
  _setBrowserFaviconColor(hex.toJS);
}
