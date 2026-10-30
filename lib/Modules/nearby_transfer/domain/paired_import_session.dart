import 'dart:async';
import 'paired_import_request.dart';

typedef ImportMessage = Future<void> Function(Map<String, dynamic> message);
typedef ImportJob =
    Future<void> Function(
      PairedImportRequest request,
      void Function(double) progress,
      bool Function() active,
    );

/// Commands only travel over the already authenticated LAN session.
class PairedImportSession {
  PairedImportSession({
    required this.host,
    required this.send,
    required this.changed,
    this.approve,
    this.execute,
  });
  final bool host;
  final ImportMessage send;
  final void Function(String state, double progress) changed;
  final Future<bool> Function(PairedImportRequest request)? approve;
  final ImportJob? execute;
  bool available = false, _closed = false, _busy = false;
  String? _id;
  final _seen = <String>{};
  Timer? _timeout;
  bool get busy => _busy;

  Future<void> announce() => send({'op': 'capabilities', 'download': host});

  Future<void> request(PairedImportRequest request) async {
    if (host || !available || _closed || _busy) throw StateError('unavailable');
    final valid = PairedImportRequest.fromJson(request.toJson());
    _id = valid.id;
    _busy = true;
    changed('waiting', 0);
    _timeout = Timer(const Duration(minutes: 40), () {
      _busy = false;
      _id = null;
      changed('failed', 0);
    });
    try {
      await send({'op': 'request', ...valid.toJson()});
    } catch (_) {
      _finish('failed');
      rethrow;
    }
  }

  Future<void> receive(Map<String, dynamic> message) async {
    if (_closed) return;
    if (message['op'] == 'capabilities') {
      if (!host) {
        available = message['download'] == true;
        changed('ready', 0);
      }
      return;
    }
    if (message['op'] == 'status' && !host) {
      if (!_busy || message['id'] != _id) return;
      final state = message['state'];
      if (![
        'waiting',
        'downloading',
        'transferring',
        'completed',
        'rejected',
        'failed',
        'busy',
      ].contains(state)) {
        return;
      }
      final raw = message['progress'];
      final progress = raw is num && raw.isFinite
          ? raw.toDouble().clamp(0.0, 1.0)
          : 0.0;
      if (['completed', 'rejected', 'failed', 'busy'].contains(state)) {
        _finish(state as String);
      } else {
        changed(state as String, progress);
      }
      return;
    }
    if (message['op'] != 'request' ||
        !host ||
        approve == null ||
        execute == null) {
      return;
    }
    PairedImportRequest request;
    try {
      request = PairedImportRequest.fromJson(message);
    } on FormatException {
      return;
    }
    if (_seen.contains(request.id)) return;
    if (_seen.length >= 128) return;
    _seen.add(request.id);
    if (_busy) {
      await send({'op': 'status', 'id': request.id, 'state': 'busy'});
      return;
    }
    _busy = true;
    _id = request.id;
    bool active() => !_closed && _id == request.id;
    Future<void> status(String state, [double progress = 0]) async {
      if (!active()) return;
      changed(state, progress);
      await send({
        'op': 'status',
        'id': request.id,
        'state': state,
        'progress': progress,
      });
    }

    try {
      await status('waiting');
      if (!await approve!(request)) {
        await status('rejected');
        return;
      }
      if (!active()) return;
      await status('downloading');
      var last = DateTime.fromMillisecondsSinceEpoch(0);
      await execute!(request, (progress) {
        final now = DateTime.now();
        if (active() && now.difference(last).inMilliseconds >= 500) {
          last = now;
          unawaited(status('downloading', progress).catchError((Object _) {}));
        }
      }, active);
      if (active()) await status('completed', 1);
    } catch (_) {
      if (active()) {
        try {
          await status('failed');
        } catch (_) {}
      }
    } finally {
      _busy = false;
      _id = null;
    }
  }

  Future<void> transferring() async {
    if (!host || _closed || _id == null) return;
    changed('transferring', 1);
    await send({
      'op': 'status',
      'id': _id,
      'state': 'transferring',
      'progress': 1,
    });
  }

  void _finish(String state) {
    _timeout?.cancel();
    _busy = false;
    _id = null;
    changed(state, state == 'completed' ? 1 : 0);
  }

  void close() {
    _closed = true;
    available = false;
    _timeout?.cancel();
    if (_busy) changed('failed', 0);
    _busy = false;
    _id = null;
  }
}
