import 'dart:convert';
import 'dart:math';

/// Versioned control messages; short codes discover a session, not authenticate it.
abstract final class HybridTransferProtocol {
  static const schema = 'listenfy.wifi-direct.v1';
  static final _random = Random.secure();
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _session = RegExp(r'^[A-Z0-9]{7}[A-Za-z0-9_-]{25,57}$');

  static String _randomText(int length) => List.generate(
    length,
    (_) => _alphabet[_random.nextInt(_alphabet.length)],
  ).join();
  static bool validCode(String code) => RegExp(r'^[A-Z0-9]{7}$').hasMatch(code);
  static String newCode() => _randomText(7);
  static String newSecret() => base64UrlEncode(
    List.generate(32, (_) => _random.nextInt(256)),
  ).replaceAll('=', '');
  static String newSessionId(String code) {
    if (!validCode(code)) throw const FormatException('Invalid code');
    return code + newSecret();
  }

  static String codeFromSession(String session) {
    if (!_session.hasMatch(session)) {
      throw const FormatException('Invalid session');
    }
    return session.substring(0, 7);
  }

  static Map<String, dynamic> createOffer({
    required String sessionId,
    required String fingerprint,
    DateTime? now,
  }) {
    final offer = <String, dynamic>{
      'schema': schema,
      'type': 'offer',
      'sessionId': sessionId,
      'networkName': 'DIRECT-LF-${_randomText(6)}',
      'passphrase': _randomText(24),
      'secret': newSecret(),
      'fingerprint': fingerprint,
      'expiresAt': (now ?? DateTime.now())
          .add(const Duration(minutes: 2))
          .millisecondsSinceEpoch,
    };
    return validateOffer(
      offer,
      expectedCode: codeFromSession(sessionId),
      now: now,
    );
  }

  static Map<String, dynamic> validateOffer(
    Map<String, dynamic> map, {
    required String expectedCode,
    String? expectedSessionId,
    DateTime? now,
  }) {
    final session = map['sessionId'];
    final expiry = map['expiresAt'];
    final time = (now ?? DateTime.now()).millisecondsSinceEpoch;
    if (!validCode(expectedCode) ||
        map['schema'] != schema ||
        map['type'] != 'offer' ||
        session is! String ||
        !_session.hasMatch(session) ||
        !session.startsWith(expectedCode) ||
        (expectedSessionId != null && session != expectedSessionId) ||
        expiry is! int ||
        expiry <= time ||
        expiry > time + 180000) {
      throw const FormatException('Invalid offer');
    }
    final network = map['networkName'], password = map['passphrase'];
    final secret = map['secret'], fingerprint = map['fingerprint'];
    if (network is! String ||
        !RegExp(r'^DIRECT-LF-[A-Z0-9]{6}$').hasMatch(network) ||
        password is! String ||
        !RegExp(r'^[\x20-\x7e]{8,63}$').hasMatch(password) ||
        secret is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(secret) ||
        fingerprint is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint)) {
      throw const FormatException('Invalid credentials');
    }
    if (base64Url.decode(base64Url.normalize(secret)).length != 32) {
      throw const FormatException('Invalid secret');
    }
    return Map<String, dynamic>.from(map);
  }

  static Map<String, dynamic> decodeMessage(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > 32768) {
      throw const FormatException('Invalid control message size');
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid message');
    }
    return value;
  }
}
