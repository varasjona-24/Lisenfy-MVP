import 'dart:collection';
import 'dart:math';

import '../../domain/entities/local_connect_models.dart';

class LocalConnectPairingManager {
  LocalConnectPairingManager({required Duration tokenTtl})
    : _tokenTtl = tokenTtl;

  final Duration _tokenTtl;
  final Random _random = Random.secure();
  static const maxPending = 32;
  static const maxSessions = 16;
  static const requestTtl = Duration(minutes: 5);
  final Map<String, LocalConnectPairingRequest> _approvedReceipts = {};

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

    if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(clientId) ||
        clientName.length > 120) {
      throw ArgumentError('Invalid pairing identity');
    }
    if (_sessionsByClientId.containsKey(clientId) ||
        findPendingByClientId(clientId) != null) {
      throw StateError('Pairing identity already in use');
    }
    if (_pendingByRequestId.length >= maxPending ||
        _sessionsByClientId.length >= maxSessions) {
      throw StateError('Pairing capacity reached');
    }

    final request = LocalConnectPairingRequest(
      id: _createToken(),
      clientId: clientId,
      clientName: clientName,
      requestedAt: DateTime.now(),
    );
    _pendingByRequestId[request.id] = request;
    return request;
  }

  LocalConnectClientSession? approveRequest(String requestId) {
    cleanupExpired();
    if (_sessionsByClientId.length >= maxSessions) return null;

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
    _approvedReceipts[session.clientId] = request;
    return session;
  }

  /// A public client id is never sufficient to retrieve a session credential.
  /// Only the browser that received this random receipt can finish pairing.
  LocalConnectClientSession? sessionForReceipt(
    String clientId,
    String receipt,
  ) {
    cleanupExpired();
    if (receipt.isEmpty || _approvedReceipts[clientId]?.id != receipt) {
      return null;
    }
    return findSessionByClientId(clientId);
  }

  LocalConnectPairingRequest? rejectRequest(String requestId) {
    return _pendingByRequestId.remove(requestId);
  }

  LocalConnectClientSession? revokeSession(String clientId) {
    cleanupExpired();
    final session = _sessionsByClientId.remove(clientId);
    if (session == null) return null;
    _clientIdByToken.remove(session.token);
    _approvedReceipts.remove(clientId);
    _pendingByRequestId.removeWhere((_, req) => req.clientId == clientId);
    return session;
  }

  List<LocalConnectClientSession> revokeAllSessions() {
    cleanupExpired();
    final revoked = _sessionsByClientId.values.toList(growable: false);
    _sessionsByClientId.clear();
    _clientIdByToken.clear();
    _approvedReceipts.clear();
    _pendingByRequestId.clear();
    return revoked;
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
    final cutoff = DateTime.now().subtract(requestTtl);
    _pendingByRequestId.removeWhere(
      (_, request) => request.requestedAt.isBefore(cutoff),
    );
    _approvedReceipts.removeWhere(
      (_, request) => request.requestedAt.isBefore(cutoff),
    );
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
        _approvedReceipts.remove(clientId);
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
}
