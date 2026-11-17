import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Owns only changes made by the video route, preserving its initial window mode.
class DesktopVideoFullscreen extends ChangeNotifier with WindowListener {
  DesktopVideoFullscreen({WindowManager? manager})
    : _manager = manager ?? windowManager;

  static bool get supported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  final WindowManager _manager;
  Future<void>? _ready;
  Future<void>? _operation;
  bool _initial = false;
  bool _changed = false;
  bool _closed = false;
  bool _value = false;
  bool get value => _value;

  Future<void> initialize() => _ready ??= _initialize();

  Future<void> _initialize() async {
    _manager.addListener(this);
    try {
      _initial = await _manager.isFullScreen();
      _update(_initial);
    } catch (_) {
      _manager.removeListener(this);
      rethrow;
    }
  }

  Future<void> toggle() {
    if (_closed) return Future.value();
    return _operation ??= _toggle().whenComplete(() => _operation = null);
  }

  Future<void> _toggle() async {
    await initialize();
    if (_closed) return;
    final next = !value;
    await _manager.setFullScreen(next);
    _changed = true;
    // macOS completes its animation after setFullScreen returns.
    for (var attempt = 0; attempt < 50; attempt++) {
      if (await _manager.isFullScreen() == next) {
        _update(next);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException(
      'The window did not finish changing fullscreen mode.',
    );
  }

  void _update(bool next) {
    if (_closed || _value == next) return;
    _value = next;
    notifyListeners();
  }

  @override
  void onWindowEnterFullScreen() => _update(true);

  @override
  void onWindowLeaveFullScreen() => _update(false);

  /// Called on route disposal. Wait for pending requests before restoring.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _manager.removeListener(this);
    super.dispose();
    await _ready;
    await _operation;
    if (_changed && await _manager.isFullScreen() != _initial) {
      await _manager.setFullScreen(_initial);
    }
  }
}
