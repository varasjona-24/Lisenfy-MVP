enum ListenfyDeepLinkTarget {
  openLocalImport,
  nearbyTransfer,
  nearbyInvite,
  unknown,
}

class ListenfyNearbyInvite {
  final String sessionId;
  final String senderName;
  final String title;
  final String subtitle;
  final int? expiresAt;

  const ListenfyNearbyInvite({
    required this.sessionId,
    required this.senderName,
    required this.title,
    required this.subtitle,
    this.expiresAt,
  });

  bool get isExpired {
    final value = expiresAt;
    if (value == null || value <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch > value;
  }
}

class ListenfyDeepLink {
  static const String _scheme = 'listenfy';
  static const String _hostOpen = 'open';
  static const String _hostTransfer = 'transfer';
  static final RegExp _nearbySessionPattern = RegExp(r'^[A-Za-z0-9_-]{32,64}$');
  static const int _maxRawQrLength = 2048;
  static const int _maxSenderLength = 64;
  static const int _maxTitleLength = 120;
  static const int _maxSubtitleLength = 180;

  static Uri buildOpenLocalImportUri() {
    return Uri(
      scheme: _scheme,
      host: _hostOpen,
      queryParameters: const <String, String>{'target': 'imports-local'},
    );
  }

  static Uri buildNearbyInviteUri({
    required String sessionId,
    required String senderName,
    required String title,
    required String subtitle,
    int? expiresAt,
  }) {
    final query = <String, String>{
      'target': 'nearby-invite',
      'sid': sessionId,
      'from': senderName,
      'title': title,
      'subtitle': subtitle,
    };
    if (expiresAt != null && expiresAt > 0) {
      query['exp'] = '$expiresAt';
    }

    return Uri(
      scheme: _scheme,
      host: _hostTransfer,
      path: '/nearby',
      queryParameters: query,
    );
  }

  static ListenfyDeepLinkTarget parseRaw(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return ListenfyDeepLinkTarget.unknown;
    if (value.length > _maxRawQrLength) return ListenfyDeepLinkTarget.unknown;
    final uri = Uri.tryParse(value);
    if (uri == null) return ListenfyDeepLinkTarget.unknown;
    return parseUri(uri);
  }

  static ListenfyDeepLinkTarget parseUri(Uri uri) {
    if (uri.scheme.toLowerCase() != _scheme) {
      return ListenfyDeepLinkTarget.unknown;
    }

    final host = uri.host.toLowerCase();
    final target = (uri.queryParameters['target'] ?? '').trim().toLowerCase();

    if (host == _hostOpen &&
        (target == 'imports-local' ||
            target == 'local-import' ||
            target == 'downloads-local')) {
      return ListenfyDeepLinkTarget.openLocalImport;
    }

    if (host == _hostTransfer &&
        (target == 'nearby-invite' ||
            (uri.path.toLowerCase().contains('nearby') &&
                uri.queryParameters.containsKey('sid')))) {
      return ListenfyDeepLinkTarget.nearbyInvite;
    }

    if (host == _hostTransfer &&
        (uri.path.toLowerCase().contains('nearby') ||
            target == 'nearby-transfer')) {
      return ListenfyDeepLinkTarget.nearbyTransfer;
    }

    return ListenfyDeepLinkTarget.unknown;
  }

  static ListenfyNearbyInvite? parseNearbyInviteRaw(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.length > _maxRawQrLength) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    return parseNearbyInviteUri(uri);
  }

  static ListenfyNearbyInvite? parseNearbyInviteUri(Uri uri) {
    if (parseUri(uri) != ListenfyDeepLinkTarget.nearbyInvite) {
      return null;
    }

    final sessionId = (uri.queryParameters['sid'] ?? '').trim();
    final senderName = (uri.queryParameters['from'] ?? '').trim();
    final title = (uri.queryParameters['title'] ?? '').trim();
    final subtitle = (uri.queryParameters['subtitle'] ?? '').trim();
    final expiresAt = int.tryParse((uri.queryParameters['exp'] ?? '').trim());

    if (sessionId.isEmpty || senderName.isEmpty) return null;
    if (!_nearbySessionPattern.hasMatch(sessionId)) return null;
    if (senderName.length > _maxSenderLength) return null;
    if (title.length > _maxTitleLength) return null;
    if (subtitle.length > _maxSubtitleLength) return null;
    if (expiresAt != null &&
        expiresAt > 0 &&
        DateTime.now().millisecondsSinceEpoch > expiresAt) {
      return null;
    }

    return ListenfyNearbyInvite(
      sessionId: sessionId,
      senderName: senderName,
      title: title,
      subtitle: subtitle,
      expiresAt: expiresAt,
    );
  }
}
