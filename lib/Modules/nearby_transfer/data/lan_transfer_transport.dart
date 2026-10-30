import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../domain/hybrid_transfer_protocol.dart';
import 'wifi_direct_transport.dart';

typedef LanApproval = Future<bool> Function(String peer, String verification);

/// Local-network transport. macOS hosts an ephemeral TLS certificate; clients
/// pin it and both users compare a transcript-bound verification before files.
class LanTransferTransport implements WifiDirectTransport {
  static const discoveryPort = 39474;
  static const protocol = 'listenfy.lan.v2';
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _temporary = <File>{};
  final _pending = <int>{};
  final _incoming = <int>{};
  final _awaitingImport = <int>{};
  SecureServerSocket? _server;
  RawDatagramSocket? _discovery;
  SecureSocket? _socket, _candidate;
  Timer? _expiry, _heartbeat;
  Future<void> _writer = Future.value();
  Future<void>? _closing;
  String? _session, _fingerprint;
  String _name = '';
  DateTime? _expires;
  DateTime _lastRead = DateTime.now();
  Directory? _directory;
  bool _pairing = false;
  int _epoch = 0;
  Uri? invitation;
  LanApproval? approve;
  void Function()? pairingStarted;
  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  void _emit(String type, [Map<String, dynamic> values = const {}]) {
    _events.add({'type': type, 'sessionId': _session, ...values});
  }

  Future<Uri> advertise({
    required String name,
    List<String>? addresses,
    bool discoverable = true,
  }) async {
    await close();
    final epoch = _epoch;
    final directory = await Directory.systemTemp.createTemp('listenfy-lan-');
    _directory = directory;
    final cert = p.join(directory.path, 'certificate.pem');
    final key = p.join(directory.path, 'private.pem');
    // macOS ships LibreSSL. No downloaded binary or persistent private key.
    final result = await Process.run('/usr/bin/openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-sha256',
      '-nodes',
      '-days',
      '1',
      '-subj',
      '/CN=Listenfy temporary transfer',
      '-keyout',
      key,
      '-out',
      cert,
    ]).timeout(const Duration(seconds: 20));
    if (result.exitCode != 0 || epoch != _epoch) {
      throw StateError('certificate_unavailable');
    }
    final pem = await File(cert).readAsString();
    final der = base64Decode(
      pem.split('-----')[2].replaceAll(RegExp(r'\s'), ''),
    );
    _fingerprint = sha256.convert(der).toString();
    final context = SecurityContext()
      ..useCertificateChain(cert)
      ..usePrivateKey(key);
    await File(key).delete();
    await File(cert).delete();
    final ips = addresses ?? await localAddresses();
    if (ips.isEmpty) throw StateError('no_local_network');
    _name = name;
    final code = HybridTransferProtocol.newCode();
    _session = HybridTransferProtocol.newSessionId(code);
    _expires = DateTime.now().add(const Duration(minutes: 5));
    _server = await SecureServerSocket.bind(
      InternetAddress.anyIPv4,
      0,
      context,
    );
    if (epoch != _epoch) {
      await _server?.close();
      throw StateError('closed');
    }
    invitation = Uri(
      scheme: 'listenfy',
      host: 'transfer',
      path: '/lan',
      queryParameters: {
        'target': 'lan-invite',
        'sid': _session!,
        'from': name,
        'hosts': ips.join(','),
        'port': '${_server!.port}',
        'fp': _fingerprint!,
        'exp': '${_expires!.millisecondsSinceEpoch}',
      },
    );
    _server!.listen(
      (socket) {
        if (_pairing || _socket != null || DateTime.now().isAfter(_expires!)) {
          socket.destroy();
          return;
        }
        _pairing = true;
        _candidate = socket;
        unawaited(_accept(socket, epoch));
      },
      onError: (Object _) {
        /* Invalid TLS handshakes do not close the invitation. */
      },
    );
    if (discoverable) {
      try {
        _discovery = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          discoveryPort,
        );
        _discovery!.listen((event) {
          if (event != RawSocketEvent.read) return;
          final packet = _discovery?.receive();
          if (packet == null ||
              packet.data.length > 256 ||
              _socket != null ||
              DateTime.now().isAfter(_expires!)) {
            return;
          }
          if (utf8.decode(packet.data, allowMalformed: true) ==
              '$protocol:$code') {
            _discovery?.send(
              utf8.encode(invitation.toString()),
              packet.address,
              packet.port,
            );
          }
        });
      } on SocketException {
        /* QR remains usable if discovery is unavailable. */
      }
    }
    _expiry = Timer(const Duration(minutes: 5), () {
      if (_socket == null) {
        _emit('error');
        unawaited(close());
      }
    });
    return invitation!;
  }

  static Future<List<String>> localAddresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    interfaces.sort(
      (a, b) => (a.name.startsWith('en') ? 0 : 1).compareTo(
        b.name.startsWith('en') ? 0 : 1,
      ),
    );
    return interfaces
        .expand((i) => i.addresses)
        .where((a) => isLocal(a.address))
        .map((a) => a.address)
        .toSet()
        .toList();
  }

  static bool isLocal(String host) {
    final ip = InternetAddress.tryParse(host);
    if (ip == null || ip.type != InternetAddressType.IPv4) return false;
    final b = ip.rawAddress;
    return b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168) ||
        b[0] == 127 ||
        (b[0] == 169 && b[1] == 254);
  }

  static Uri validateInvite(Uri uri) {
    final q = uri.queryParameters;
    final hosts = (q['hosts'] ?? '').split(',');
    final port = int.tryParse(q['port'] ?? '');
    final expiry = int.tryParse(q['exp'] ?? '');
    final now = DateTime.now().millisecondsSinceEpoch;
    if (uri.scheme != 'listenfy' ||
        uri.host != 'transfer' ||
        uri.path != '/lan' ||
        q['target'] != 'lan-invite' ||
        hosts.isEmpty ||
        hosts.length > 16 ||
        !hosts.every(isLocal) ||
        port == null ||
        port < 1 ||
        port > 65535 ||
        expiry == null ||
        expiry <= now ||
        expiry > now + 330000 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(q['fp'] ?? '') ||
        !RegExp(
          r'^[A-Z0-9]{7}[A-Za-z0-9_-]{25,57}$',
        ).hasMatch(q['sid'] ?? '')) {
      throw const FormatException('Invalid LAN invitation');
    }
    return uri;
  }

  Future<Uri> discover(String code) async {
    if (!HybridTransferProtocol.validCode(code)) {
      throw const FormatException('code');
    }
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final result = Completer<Uri>();
    final data = utf8.encode('$protocol:$code');
    final targets = <String>{'255.255.255.255'};
    for (final ip in await localAddresses()) {
      targets.add('${ip.substring(0, ip.lastIndexOf('.'))}.255');
    }
    void search() {
      for (final address in targets) {
        try {
          socket.send(data, InternetAddress(address), discoveryPort);
        } on SocketException {
          /* next interface */
        }
      }
    }

    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read || result.isCompleted) return;
      final packet = socket.receive();
      if (packet == null || packet.data.length > 2048) return;
      try {
        final invite = validateInvite(Uri.parse(utf8.decode(packet.data)));
        if (invite.queryParameters['sid']!.startsWith(code)) {
          result.complete(invite);
        }
      } on FormatException {
        /* Not a valid invitation. */
      }
    });
    final retry = Timer.periodic(const Duration(seconds: 1), (_) => search());
    search();
    try {
      return await result.future.timeout(const Duration(seconds: 15));
    } finally {
      retry.cancel();
      await sub.cancel();
      socket.close();
    }
  }

  Future<void> connect(Uri raw, {required String name}) async {
    final uri = validateInvite(raw);
    await close();
    final epoch = _epoch;
    _name = name;
    _session = uri.queryParameters['sid'];
    _fingerprint = uri.queryParameters['fp'];
    SecureSocket? socket;
    for (final host in uri.queryParameters['hosts']!.split(',')) {
      try {
        socket = await SecureSocket.connect(
          host,
          int.parse(uri.queryParameters['port']!),
          context: SecurityContext(withTrustedRoots: false),
          onBadCertificate: (cert) =>
              sha256.convert(cert.der).toString() == _fingerprint,
          timeout: const Duration(seconds: 6),
        );
        if (sha256.convert(socket.peerCertificate!.der).toString() !=
            _fingerprint) {
          socket.destroy();
          socket = null;
          continue;
        }
        break;
      } on SocketException {
        /* Try the next host interface. */
      } on HandshakeException {
        /* Reject invalid certificate. */
      }
    }
    if (socket == null || epoch != _epoch) {
      socket?.destroy();
      throw StateError('not_found');
    }
    _candidate = socket;
    final wire = _LanWire(socket);
    try {
      final nonce = HybridTransferProtocol.newSecret();
      await wire.write({
        'type': 'hello',
        'protocol': protocol,
        'sessionId': _session,
        'name': name,
        'nonce': nonce,
      });
      final hello = await wire
          .header(maxBytes: 4096)
          .timeout(const Duration(seconds: 15));
      _validateHello(hello);
      final verification = _verification(nonce, hello['nonce'] as String);
      pairingStarted?.call();
      final accepted =
          await (approve?.call(hello['name'] as String, verification) ??
                  Future.value(false))
              .timeout(const Duration(seconds: 90));
      if (epoch != _epoch) throw StateError('closed');
      await wire.write({'type': 'decision', 'accepted': accepted});
      final peer = await wire.header();
      if (!accepted || peer['type'] != 'decision' || peer['accepted'] != true) {
        socket.destroy();
        _candidate = null;
        _emit('rejected');
        return;
      }
      _attach(socket, wire, hello['name'] as String, epoch);
    } catch (_) {
      socket.destroy();
      rethrow;
    }
  }

  Future<void> _accept(SecureSocket socket, int epoch) async {
    final wire = _LanWire(socket);
    try {
      final hello = await wire
          .header(maxBytes: 4096)
          .timeout(const Duration(seconds: 15));
      _validateHello(hello);
      final nonce = HybridTransferProtocol.newSecret();
      await wire.write({
        'type': 'hello',
        'protocol': protocol,
        'sessionId': _session,
        'name': _name,
        'nonce': nonce,
      });
      pairingStarted?.call();
      final accepted =
          await (approve?.call(
                    hello['name'] as String,
                    _verification(hello['nonce'] as String, nonce),
                  ) ??
                  Future.value(false))
              .timeout(const Duration(seconds: 90));
      if (epoch != _epoch) throw StateError('closed');
      await wire.write({'type': 'decision', 'accepted': accepted});
      final peer = await wire.header();
      if (!accepted || peer['type'] != 'decision' || peer['accepted'] != true) {
        socket.destroy();
        _emit('rejected');
        return;
      }
      _attach(socket, wire, hello['name'] as String, epoch);
    } catch (_) {
      socket.destroy();
      if (epoch == _epoch) _emit('rejected');
    } finally {
      if (epoch == _epoch) {
        _pairing = false;
        _candidate = null;
      }
    }
  }

  void _validateHello(Map<String, dynamic> hello) {
    if (hello['type'] != 'hello' ||
        hello['protocol'] != protocol ||
        hello['sessionId'] != _session ||
        hello['name'] is! String ||
        (hello['name'] as String).length > 64 ||
        hello['nonce'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(hello['nonce'] as String)) {
      throw const FormatException('Invalid association');
    }
  }

  String _verification(String clientNonce, String hostNonce) {
    final hash = sha256
        .convert(
          utf8.encode(
            '$protocol|$_session|$_fingerprint|$clientNonce|$hostNonce',
          ),
        )
        .toString()
        .substring(0, 12)
        .toUpperCase();
    return '${hash.substring(0, 4)} ${hash.substring(4, 8)} ${hash.substring(8)}';
  }

  void _attach(SecureSocket socket, _LanWire wire, String peer, int epoch) {
    if (epoch != _epoch) {
      socket.destroy();
      return;
    }
    _socket = socket;
    _candidate = null;
    _expiry?.cancel();
    _discovery?.close();
    _discovery = null;
    _lastRead = DateTime.now();
    _emit('connected', {'peerName': peer});
    _heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
      if (DateTime.now().difference(_lastRead).inSeconds > 60) {
        _emit('closed');
        unawaited(close());
      } else {
        unawaited(
          _queue(
            () => wire.write({'type': 'ping', 'sessionId': _session}),
          ).catchError((Object _) {}),
        );
      }
    });
    _wire = wire;
    unawaited(_pump(wire, epoch));
  }

  Future<void> sendControl(Map<String, dynamic> message) {
    if (utf8.encode(jsonEncode(message)).length > 8192) {
      throw const FormatException('control_size');
    }
    return _queue(
      () => _wire!.write({
        'type': 'control',
        'sessionId': _session,
        'message': message,
      }),
    );
  }

  _LanWire? _wire;
  Future<void> _queue(Future<void> Function() action) {
    final epoch = _epoch;
    final operation = _writer.then((_) async {
      if (epoch != _epoch || _socket == null) throw StateError('closed');
      await action();
    });
    _writer = operation.catchError((Object _) {});
    return operation;
  }

  static (int, int) _validateDescriptor(
    Map<String, dynamic> d,
    String session, {
    bool cover = false,
  }) {
    final id = d['payloadId'], size = d['sizeBytes'];
    final allowed = cover
        ? {'png', 'jpg', 'gif', 'webp'}
        : {
            'mp3',
            'm4a',
            'aac',
            'wav',
            'flac',
            'ogg',
            'opus',
            'mp4',
            'mkv',
            'webm',
          };
    if (id is! int ||
        id < 0 ||
        size is! int ||
        size <= 0 ||
        size > (cover ? 67108864 : 1073741824) ||
        d['sessionId'] != session ||
        d['sha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(d['sha256'] as String) ||
        !allowed.contains(d['format']) ||
        (!cover && (d['kind'] != 'audio' && d['kind'] != 'video'))) {
      throw const FormatException('Invalid file descriptor');
    }
    return (id, size);
  }

  @override
  Future<void> send(
    String path,
    Map<String, dynamic> descriptor, {
    String? coverPath,
  }) {
    final epoch = _epoch;
    return _queue(() async {
      final wire = _wire!;
      final (id, size) = _validateDescriptor(descriptor, _session!);
      if (!_pending.add(id)) throw StateError('Duplicate payload');
      final header = {
        'type': 'file',
        'sessionId': _session,
        'descriptor': descriptor,
      };
      _LanWire.encodeHeader(header);
      final cover = descriptor['cover'];
      if (cover is Map && coverPath != null) {
        final attachment = Map<String, dynamic>.from(cover)
          ..addAll({'payloadId': id, 'sessionId': _session});
        final (_, coverSize) = _validateDescriptor(
          attachment,
          _session!,
          cover: true,
        );
        await wire.write({
          'type': 'cover',
          'sessionId': _session,
          'descriptor': attachment,
        });
        await _writeFile(
          wire,
          File(coverPath),
          coverSize,
          id,
          attachment['sha256'] as String,
          false,
        );
      }
      await wire.write(header);
      await _writeFile(
        wire,
        File(path),
        size,
        id,
        descriptor['sha256'] as String,
        true,
      );
    }).catchError((Object error, StackTrace stack) async {
      if (epoch == _epoch) {
        _emit('closed');
        await close();
      }
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _writeFile(
    _LanWire wire,
    File file,
    int size,
    int id,
    String expected,
    bool progress,
  ) async {
    if (await file.length() != size) throw StateError('Source changed');
    final hash = _DigestSink();
    final digest = sha256.startChunkedConversion(hash);
    var count = 0;
    await for (final bytes in file.openRead()) {
      if (_socket != wire.socket) throw StateError('closed');
      count += bytes.length;
      if (count > size) throw StateError('Source changed');
      digest.add(bytes);
      wire.socket.add(bytes);
      await wire.socket.flush();
      if (progress) {
        _emit('progress', {
          'payloadId': id,
          'direction': 'sent',
          'bytes': count,
          'total': size,
        });
      }
    }
    digest.close();
    if (count != size || hash.value.toString() != expected) {
      throw StateError('Source changed');
    }
  }

  Future<void> _pump(_LanWire wire, int epoch) async {
    (int, File, String)? cover;
    try {
      while (epoch == _epoch) {
        final header = await wire.header();
        if (epoch != _epoch) return;
        _lastRead = DateTime.now();
        if (header['sessionId'] != _session) {
          throw const FormatException('session');
        }
        switch (header['type']) {
          case 'control':
            final message = header['message'];
            if (message is! Map<String, dynamic> ||
                utf8.encode(jsonEncode(message)).length > 8192) {
              throw const FormatException('control');
            }
            _emit('control', {'message': message});
          case 'ping':
            // Never stop the reader waiting for our writer: both peers may
            // be sending large files concurrently with TCP backpressure.
            unawaited(
              _queue(
                () => wire.write({'type': 'pong', 'sessionId': _session}),
              ).catchError((Object _) {}),
            );
          case 'pong':
            break;
          case 'ack':
            final id = header['payloadId'];
            if (id is! int || !_pending.remove(id)) {
              throw const FormatException('ack');
            }
            _emit('sent', {'payloadId': id});
          case 'file':
          case 'cover':
            final isCover = header['type'] == 'cover';
            final d = Map<String, dynamic>.from(header['descriptor'] as Map);
            final (id, size) = _validateDescriptor(
              d,
              _session!,
              cover: isCover,
            );
            if (_incoming.contains(id) || (isCover && cover != null)) {
              throw const FormatException('duplicate');
            }
            _directory ??= await Directory.systemTemp.createTemp(
              'listenfy-lan-incoming-',
            );
            final file = File(
              p.join(
                _directory!.path,
                '${HybridTransferProtocol.newSecret()}.part',
              ),
            );
            _temporary.add(file);
            final output = await file.open(mode: FileMode.write);
            final hash = _DigestSink();
            final digest = sha256.startChunkedConversion(hash);
            var count = 0;
            try {
              while (count < size) {
                final bytes = await wire.read(min(65536, size - count));
                if (epoch != _epoch) throw StateError('closed');
                _lastRead = DateTime.now();
                count += bytes.length;
                digest.add(bytes);
                await output.writeFrom(bytes);
                if (epoch != _epoch) throw StateError('closed');
                if (!isCover) {
                  _emit('progress', {
                    'payloadId': id,
                    'direction': 'received',
                    'bytes': count,
                    'total': size,
                  });
                }
              }
            } finally {
              await output.close();
              digest.close();
            }
            if (hash.value.toString() != d['sha256']) {
              throw const FormatException('integrity');
            }
            if (isCover) {
              cover = (id, file, d['sha256'] as String);
            } else {
              if (d['cover'] is Map &&
                  (cover == null ||
                      cover.$1 != id ||
                      cover.$3 != (d['cover'] as Map)['sha256'])) {
                throw const FormatException('cover');
              }
              if (d['cover'] == null && cover != null) {
                throw const FormatException('cover');
              }
              _incoming.add(id);
              _awaitingImport.add(id);
              _emit('received', {
                'descriptor': d,
                'path': file.path,
                'coverPath': cover?.$2.path ?? '',
              });
              cover = null;
            }
          default:
            throw const FormatException('frame');
        }
      }
    } catch (_) {
      if (epoch == _epoch) {
        _emit('closed');
        await close();
      }
    }
  }

  @override
  Future<void> confirm(int payloadId) => _queue(() async {
    if (!_awaitingImport.remove(payloadId)) throw StateError('Unknown payload');
    await _wire!.write({
      'type': 'ack',
      'sessionId': _session,
      'payloadId': payloadId,
    });
    _temporary.removeWhere((file) => !file.existsSync());
  });
  @override
  Future<void> close() {
    final previous = _closing;
    if (previous != null) return previous;
    final operation = _close();
    _closing = operation;
    return operation.whenComplete(() {
      if (identical(_closing, operation)) _closing = null;
    });
  }

  Future<void> _close() async {
    _epoch++;
    _expiry?.cancel();
    _heartbeat?.cancel();
    _discovery?.close();
    _discovery = null;
    _candidate?.destroy();
    _candidate = null;
    _socket?.destroy();
    _socket = null;
    await _server?.close();
    _server = null;
    _wire = null;
    _pairing = false;
    _pending.clear();
    _incoming.clear();
    _awaitingImport.clear();
    for (final file in _temporary.toList()) {
      try {
        await file.delete();
      } on FileSystemException {
        /* Already imported. */
      }
    }
    _temporary.clear();
    final directory = _directory;
    _directory = null;
    if (directory != null) {
      try {
        await directory.delete(recursive: true);
      } on FileSystemException {
        /* Already cleaned. */
      }
    }
    invitation = null;
    _session = null;
    _fingerprint = null;
    _writer = Future.value();
  }

  @override
  Future<String> prepare(Map<String, dynamic> credentials) =>
      throw UnsupportedError('Use LAN invitation');
  @override
  Future<void> startHost() => throw UnsupportedError('Use LAN invitation');
  @override
  Future<void> join(Map<String, dynamic> credentials) =>
      throw UnsupportedError('Use LAN invitation');
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

class _LanWire {
  _LanWire(this.socket) : input = StreamIterator(socket);
  final SecureSocket socket;
  final StreamIterator<Uint8List> input;
  Uint8List _buffer = Uint8List(0);
  int _offset = 0;
  Future<Uint8List> read(int length) async {
    final result = Uint8List(length);
    var written = 0;
    while (written < length) {
      if (_offset == _buffer.length) {
        if (!await input.moveNext().timeout(const Duration(seconds: 110))) {
          throw const SocketException('Peer closed');
        }
        _buffer = input.current;
        _offset = 0;
      }
      final count = min(length - written, _buffer.length - _offset);
      result.setRange(written, written + count, _buffer, _offset);
      written += count;
      _offset += count;
    }
    return result;
  }

  static Uint8List encodeHeader(Map<String, dynamic> header) {
    final body = utf8.encode(jsonEncode(header));
    if (body.isEmpty || body.length > 262144) {
      throw const FormatException('Header size');
    }
    final data = Uint8List(4 + body.length);
    ByteData.sublistView(data).setUint32(0, body.length);
    data.setRange(4, data.length, body);
    return data;
  }

  Future<void> write(Map<String, dynamic> header) async {
    socket.add(encodeHeader(header));
    await socket.flush();
  }

  Future<Map<String, dynamic>> header({int maxBytes = 262144}) async {
    final length = ByteData.sublistView(await read(4)).getUint32(0);
    if (length == 0 || length > maxBytes) {
      throw const FormatException('Header size');
    }
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(await read(length))) as Map,
    );
  }
}
