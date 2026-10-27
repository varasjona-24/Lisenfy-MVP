import 'dart:io';
import 'package:crypto/crypto.dart';

/// The original cover travels as a bounded binary attachment, never JSON/base64.
class TransferCoverAttachment {
  const TransferCoverAttachment(this.path, this.size, this.hash, this.format);
  static const maxBytes = 64 * 1024 * 1024;
  final String path, hash, format;
  final int size;
  Map<String, dynamic> toJson() => {
    'sizeBytes': size,
    'sha256': hash,
    'format': format,
  };

  static Future<TransferCoverAttachment?> read(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    try {
      final file = File(path);
      final size = await file.length();
      if (size <= 0 || size > maxBytes) return null;
      final handle = await file.open();
      late List<int> header;
      try {
        header = await handle.read(12);
      } finally {
        await handle.close();
      }
      final format = imageFormat(header);
      if (format == null) return null;
      final hash = (await sha256.bind(file.openRead()).first).toString();
      return TransferCoverAttachment(path, size, hash, format);
    } on FileSystemException {
      return null;
    }
  }

  static String? imageFormat(List<int> b) {
    if (b.length < 12) return null;
    if (b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4e &&
        b[3] == 0x47 &&
        b[4] == 13 &&
        b[5] == 10 &&
        b[6] == 26 &&
        b[7] == 10) {
      return 'png';
    }
    if (b[0] == 255 && b[1] == 216 && b[2] == 255) return 'jpg';
    if (String.fromCharCodes(b.take(6)) == 'GIF87a' ||
        String.fromCharCodes(b.take(6)) == 'GIF89a') {
      return 'gif';
    }
    if (String.fromCharCodes(b.take(4)) == 'RIFF' &&
        String.fromCharCodes(b.skip(8).take(4)) == 'WEBP') {
      return 'webp';
    }
    return null;
  }
}
