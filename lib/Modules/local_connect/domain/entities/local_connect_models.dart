class LocalConnectPairingRequest {
  const LocalConnectPairingRequest({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.requestedAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final DateTime requestedAt;

  LocalConnectPairingRequest copyWith({
    String? id,
    String? clientId,
    String? clientName,
    DateTime? requestedAt,
  }) {
    return LocalConnectPairingRequest(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      requestedAt: requestedAt ?? this.requestedAt,
    );
  }
}

class LocalConnectClientSession {
  const LocalConnectClientSession({
    required this.clientId,
    required this.clientName,
    required this.token,
    required this.approvedAt,
    required this.expiresAt,
    required this.lastSeenAt,
    required this.isConnected,
  });

  final String clientId;
  final String clientName;
  final String token;
  final DateTime approvedAt;
  final DateTime expiresAt;
  final DateTime lastSeenAt;
  final bool isConnected;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  LocalConnectClientSession copyWith({
    String? clientId,
    String? clientName,
    String? token,
    DateTime? approvedAt,
    DateTime? expiresAt,
    DateTime? lastSeenAt,
    bool? isConnected,
  }) {
    return LocalConnectClientSession(
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      token: token ?? this.token,
      approvedAt: approvedAt ?? this.approvedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}
