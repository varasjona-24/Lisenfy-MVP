import 'dart:io';

enum PairedImportFormat { mp3, m4a, mp4 }

/// Small, allowlisted request; never accepts executable names or local paths.
class PairedImportRequest {
  const PairedImportRequest({
    required this.id,
    required this.url,
    required this.format,
  });
  final String id;
  final String url;
  final PairedImportFormat format;
  String get kind => format == PairedImportFormat.mp4 ? 'video' : 'audio';

  static String validateUrl(String input) {
    if (input.length > 2048) throw const FormatException('url');
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        uri.hasFragment) {
      throw const FormatException('url');
    }
    final host = uri.host.toLowerCase();
    final labels = host.split('.');
    if (host.isEmpty ||
        InternetAddress.tryParse(host) != null ||
        labels.length < 2 ||
        labels.any(
          (label) => !RegExp(
            r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
          ).hasMatch(label),
        ) ||
        [
          'local',
          'localhost',
          'internal',
          'lan',
          'home',
          'test',
          'invalid',
        ].contains(labels.last)) {
      throw const FormatException('url');
    }
    return uri.toString();
  }

  /// Check the initial destination on the computer before invoking yt-dlp.
  Future<void> validateDestination({
    Future<List<InternetAddress>> Function(String)? lookup,
  }) async {
    final addresses = await (lookup ?? InternetAddress.lookup)(
      Uri.parse(url).host,
    );
    if (addresses.isEmpty ||
        addresses.any((address) => !isPublicAddress(address))) {
      throw const FormatException('private_destination');
    }
  }

  static bool isPublicAddress(InternetAddress address) {
    final b = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return !(b[0] == 0 ||
          b[0] == 10 ||
          b[0] == 127 ||
          b[0] >= 224 ||
          (b[0] == 100 && b[1] >= 64 && b[1] <= 127) ||
          (b[0] == 169 && b[1] == 254) ||
          (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
          (b[0] == 192 &&
              (b[1] == 168 || b[1] == 0 || (b[1] == 88 && b[2] == 99))) ||
          (b[0] == 198 &&
              (b[1] == 18 || b[1] == 19 || (b[1] == 51 && b[2] == 100))) ||
          (b[0] == 203 && b[1] == 0 && b[2] == 113));
    }
    return (b[0] & 0xe0) == 0x20 &&
        !(b[0] == 0x20 && b[1] == 0x01 && b[2] == 0x0d && b[3] == 0xb8);
  }

  factory PairedImportRequest.fromJson(Map<String, dynamic> data) {
    final id = data['id'];
    if (id is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
      throw const FormatException('id');
    }
    final format = PairedImportFormat.values
        .where((value) => value.name == data['format'])
        .firstOrNull;
    if (format == null || data['url'] is! String) {
      throw const FormatException('request');
    }
    return PairedImportRequest(
      id: id,
      url: validateUrl(data['url'] as String),
      format: format,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'format': format.name,
  };
}
