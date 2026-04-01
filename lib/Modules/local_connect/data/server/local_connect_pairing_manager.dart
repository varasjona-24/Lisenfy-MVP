import 'dart:collection';
import 'dart:math';

import '../../domain/entities/local_connect_models.dart';

class LocalConnectPairingManager {
  LocalConnectPairingManager({required Duration tokenTtl})
    : _tokenTtl = tokenTtl;

  final Duration _tokenTtl;
  final Random _random = Random.secure();

  final Map<String, LocalConnectPairingRequest> _pendingByRequestId =
      <String, LocalConnectPairingRequest>{};
  final Map<String, LocalConnectClientSession> _sessionsByClientId =
      <String, LocalConnectClientSession>{};
  final Map<String, String> _clientIdByToken = <String, String>{};

  UnmodifiableListView<LocalConnectPairingRequest> get pendingRequests {
    final values = _pendingByRequestId.values.toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return UnmodifiableListView<LocalConnectPairingRequest>(values);
  }

  UnmodifiableListView<LocalConnectClientSession> get sessions {
    final values = _sessionsByClientId.values.toList()
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    return UnmodifiableListView<LocalConnectClientSession>(values);
  }

  LocalConnectPairingRequest requestPairing({
    required String clientId,
    required String clientName,
  }) {
    cleanupExpired();

    final active = _sessionsByClientId[clientId];
    if (active != null && !active.isExpired) {
      return LocalConnectPairingRequest(
        id: _buildId('paired'),
        clientId: clientId,
        clientName: clientName,
        requestedAt: DateTime.now(),
      );
    }

    final existing = _pendingByRequestId.values.where((req) {
      return req.clientId == clientId;
    }).toList();

    for (final req in existing) {
      _pendingByRequestId.remove(req.id);
    }

    final request = LocalConnectPairingRequest(
      id: _buildId('pair'),
      clientId: clientId,
      clientName: clientName,
      requestedAt: DateTime.now(),
    );
    _pendingByRequestId[request.id] = request;
    return request;
  }

  LocalConnectClientSession? approveRequest(String requestId) {
    cleanupExpired();

    final request = _pendingByRequestId.remove(requestId);
    if (request == null) return null;

    final existing = _sessionsByClientId[request.clientId];
    if (existing != null) {
      _clientIdByToken.remove(existing.token);
    }

    final now = DateTime.now();
    final session = LocalConnectClientSession(
      clientId: request.clientId,
      clientName: request.clientName,
      token: _createToken(),
      approvedAt: now,
      expiresAt: now.add(_tokenTtl),
      lastSeenAt: now,
      isConnected: existing?.isConnected ?? false,
    );

    _sessionsByClientId[session.clientId] = session;
    _clientIdByToken[session.token] = session.clientId;
    return session;
  }

  LocalConnectPairingRequest? rejectRequest(String requestId) {
    return _pendingByRequestId.remove(requestId);
  }

  LocalConnectPairingRequest? findPendingByClientId(String clientId) {
    if (clientId.trim().isEmpty) return null;
    final pending =
        _pendingByRequestId.values
            .where((req) => req.clientId == clientId)
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    if (pending.isEmpty) return null;
    return pending.first;
  }

  LocalConnectClientSession? findSessionByToken(String token) {
    cleanupExpired();
    final clientId = _clientIdByToken[token];
    if (clientId == null) return null;
    final session = _sessionsByClientId[clientId];
    if (session == null || session.isExpired) return null;
    return session;
  }

  LocalConnectClientSession? findSessionByClientId(String clientId) {
    cleanupExpired();
    final session = _sessionsByClientId[clientId];
    if (session == null || session.isExpired) return null;
    return session;
  }

  bool isTokenAuthorized({required String token, String? clientId}) {
    final session = findSessionByToken(token);
    if (session == null) return false;
    if (clientId != null &&
        clientId.isNotEmpty &&
        session.clientId != clientId) {
      return false;
    }
    return true;
  }

  LocalConnectClientSession? touchClient({
    required String clientId,
    bool? isConnected,
    bool refreshExpiry = true,
  }) {
    cleanupExpired();
    final session = _sessionsByClientId[clientId];
    if (session == null || session.isExpired) return null;

    final now = DateTime.now();
    final updated = session.copyWith(
      lastSeenAt: now,
      isConnected: isConnected ?? session.isConnected,
      expiresAt: refreshExpiry ? now.add(_tokenTtl) : session.expiresAt,
    );
    _sessionsByClientId[clientId] = updated;
    return updated;
  }

  void disconnectClient(String clientId) {
    final session = _sessionsByClientId[clientId];
    if (session == null) return;
    _sessionsByClientId[clientId] = session.copyWith(
      isConnected: false,
      lastSeenAt: DateTime.now(),
    );
  }

  void cleanupExpired() {
    final expiredClientIds = <String>[];
    _sessionsByClientId.forEach((clientId, session) {
      if (session.isExpired) {
        expiredClientIds.add(clientId);
      }
    });

    for (final clientId in expiredClientIds) {
      final removed = _sessionsByClientId.remove(clientId);
      if (removed != null) {
        _clientIdByToken.remove(removed.token);
      }
    }
  }

  String _createToken() {
    final alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
    final buffer = StringBuffer();
    for (var i = 0; i < 56; i++) {
      buffer.write(alphabet[_random.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  String _buildId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = _random.nextInt(1 << 31);
    return '$prefix-$now-$random';
  }
}
