import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/nearby_transfer/domain/hybrid_transfer_protocol.dart';

void main() {
  final now = DateTime(2026, 10, 22, 12);
  late String code, session;
  late Map<String, dynamic> offer;
  setUp(() {
    code = HybridTransferProtocol.newCode();
    session = HybridTransferProtocol.newSessionId(code);
    offer = HybridTransferProtocol.createOffer(
      sessionId: session,
      fingerprint: 'a' * 64,
      now: now,
    );
  });
  test('secure invitations meet QR and short-code contracts', () {
    expect(HybridTransferProtocol.validCode(code), isTrue);
    expect(HybridTransferProtocol.codeFromSession(session), code);
    expect(session.length, inInclusiveRange(32, 64));
    expect(HybridTransferProtocol.newSessionId(code), isNot(session));
    expect(
      HybridTransferProtocol.validateOffer(
        offer,
        expectedCode: code,
        expectedSessionId: session,
        now: now,
      ),
      offer,
    );
  });
  for (final invalid in ['', 'ABC123', 'ABC12345', 'abc1234', 'AB!1234']) {
    test('rejects invalid short code $invalid', () {
      expect(HybridTransferProtocol.validCode(invalid), isFalse);
    });
  }
  test('rejects expired or distant future offers', () {
    for (final delta in [-1, 0, 180001]) {
      offer['expiresAt'] = now.millisecondsSinceEpoch + delta;
      expect(
        () => HybridTransferProtocol.validateOffer(
          offer,
          expectedCode: code,
          now: now,
        ),
        throwsFormatException,
      );
    }
  });
  test('rejects another session or invitation code', () {
    expect(
      () => HybridTransferProtocol.validateOffer(
        offer,
        expectedCode: code,
        expectedSessionId: HybridTransferProtocol.newSessionId(code),
        now: now,
      ),
      throwsFormatException,
    );
    expect(
      () => HybridTransferProtocol.validateOffer(
        offer,
        expectedCode: code == 'AAAAAAA' ? 'BBBBBBB' : 'AAAAAAA',
        now: now,
      ),
      throwsFormatException,
    );
  });
  for (final field in ['fingerprint', 'secret', 'networkName', 'passphrase']) {
    test('rejects invalid $field', () {
      offer[field] = 'invalid';
      expect(
        () => HybridTransferProtocol.validateOffer(
          offer,
          expectedCode: code,
          now: now,
        ),
        throwsFormatException,
      );
    });
  }
  test('strictly bounds and decodes control messages', () {
    expect(
      HybridTransferProtocol.decodeMessage(utf8.encode(jsonEncode(offer))),
      offer,
    );
    for (final bytes in [
      <int>[],
      List.filled(32769, 32),
      [255],
      utf8.encode('[]'),
    ]) {
      expect(
        () => HybridTransferProtocol.decodeMessage(bytes),
        throwsFormatException,
      );
    }
  });
}
