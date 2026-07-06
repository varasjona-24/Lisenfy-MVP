import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/local_connect/data/server/local_connect_pairing_manager.dart';

void main() {
  group('LocalConnectPairingManager', () {
    test('revoca una sesion y desautoriza su token', () {
      final manager = LocalConnectPairingManager(
        tokenTtl: const Duration(minutes: 15),
      );

      final request = manager.requestPairing(
        clientId: 'browser-1',
        clientName: 'Laptop',
      );
      final session = manager.approveRequest(request.id);

      expect(session, isNotNull);
      expect(
        manager.isTokenAuthorized(
          token: session!.token,
          clientId: session.clientId,
        ),
        isTrue,
      );

      final revoked = manager.revokeSession(session.clientId);

      expect(revoked?.clientId, session.clientId);
      expect(manager.findSessionByClientId(session.clientId), isNull);
      expect(manager.findSessionByToken(session.token), isNull);
      expect(
        manager.isTokenAuthorized(
          token: session.token,
          clientId: session.clientId,
        ),
        isFalse,
      );
    });

    test('revoca todas las sesiones y limpia tokens', () {
      final manager = LocalConnectPairingManager(
        tokenTtl: const Duration(minutes: 15),
      );

      final firstRequest = manager.requestPairing(
        clientId: 'browser-1',
        clientName: 'Laptop',
      );
      final secondRequest = manager.requestPairing(
        clientId: 'browser-2',
        clientName: 'Tablet',
      );
      final first = manager.approveRequest(firstRequest.id)!;
      final second = manager.approveRequest(secondRequest.id)!;

      final revoked = manager.revokeAllSessions();

      expect(revoked.map((session) => session.clientId), contains('browser-1'));
      expect(revoked.map((session) => session.clientId), contains('browser-2'));
      expect(manager.sessions, isEmpty);
      expect(manager.isTokenAuthorized(token: first.token), isFalse);
      expect(manager.isTokenAuthorized(token: second.token), isFalse);
    });
  });
}
