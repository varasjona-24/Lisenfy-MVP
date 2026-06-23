import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/models/media_item.dart';
import '../../../Modules/captures/data/capture_gallery_store.dart';
import '../../../Modules/playlists/data/playlist_store.dart';
import '../../../Modules/artists/data/artist_store.dart';
import '../../../Modules/sources/data/source_theme_pill_store.dart';
import '../../../Modules/sources/data/source_theme_topic_store.dart';
import '../../../Modules/sources/data/source_theme_topic_playlist_store.dart';
import '../../../Modules/playlists/controller/playlists_controller.dart';
import '../../../Modules/artists/controller/artists_controller.dart';
import '../../../Modules/sources/controller/sources_controller.dart';
import '../../../Modules/playlists/domain/playlist.dart';
import '../../../Modules/artists/domain/artist_profile.dart';
import '../../../Modules/sources/domain/source_theme_pill.dart';
import '../../../Modules/sources/domain/source_theme_topic.dart';
import '../../../Modules/sources/domain/source_theme_topic_playlist.dart';
import '../../../Modules/downloads/controller/downloads_controller.dart';
import '../../../Modules/Home/Controller/home_controller.dart';
import '../../../Modules/recommendations/data/recommendation_store.dart';
import '../../../Modules/recommendations/data/recommendation_feedback_store.dart';
import '../../../Modules/recommendations/application/recommendation_feedback_service.dart';
import '../../../Modules/recommendations/domain/contracts/recommendation_engine.dart';
import 'settings_controller.dart';

// Empaqueta un directorio en ZIP (sin compresión / STORE) fuera del hilo
// principal para evitar ANR. STORE es mucho más rápido que Deflate porque no
// necesita trabajo de CPU; el resultado es portátil y puede compartirse o
// restaurarse exactamente igual que un ZIP comprimido.
void _createZipIsolate(Map<String, dynamic> params) {
  final sourceDir = params['sourceDir'] as String;
  final zipPath = params['zipPath'] as String;

  final encoder = ZipFileEncoder();
  // level: 0 → método STORE (sin compresión), el más rápido posible.
  encoder.create(zipPath, level: 0);
  encoder.addDirectory(Directory(sourceDir), includeDirName: false);
  encoder.close();
}

class _ZipBackupEntry {
  const _ZipBackupEntry({
    required this.name,
    required this.compressionMethod,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
    required this.isDirectory,
  });

  final String name;
  final int compressionMethod;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
  final bool isDirectory;
}

class _ZipBackupIndex {
  const _ZipBackupIndex(this.entries);

  final Map<String, _ZipBackupEntry> entries;

  _ZipBackupEntry? find(String name) => entries[_normalizeZipName(name)];
}

int _readUint16Le(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes, offset, offset + 2).getUint16(0, Endian.little);

int _readUint32Le(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes, offset, offset + 4).getUint32(0, Endian.little);

int _readUint64Le(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes, offset, offset + 8).getUint64(0, Endian.little);

String _normalizeZipName(String name) {
  var clean = name.replaceAll('\\', '/').trim();
  while (clean.startsWith('/')) {
    clean = clean.substring(1);
  }
  clean = p.posix.normalize(clean);
  return clean == '.' ? '' : clean;
}

class _Zip64CentralDirectoryInfo {
  const _Zip64CentralDirectoryInfo({required this.size, required this.offset});

  final int size;
  final int offset;
}

class _Zip64EntryInfo {
  const _Zip64EntryInfo({
    this.uncompressedSize,
    this.compressedSize,
    this.localHeaderOffset,
  });

  final int? uncompressedSize;
  final int? compressedSize;
  final int? localHeaderOffset;
}

Future<_Zip64CentralDirectoryInfo> _readZip64CentralDirectoryInfo({
  required RandomAccessFile raf,
  required Uint8List tail,
  required int eocdOffset,
}) async {
  var locatorOffset = -1;
  for (var i = eocdOffset - 20; i >= 0; i--) {
    if (_readUint32Le(tail, i) == 0x07064b50) {
      locatorOffset = i;
      break;
    }
  }
  if (locatorOffset < 0 || locatorOffset + 20 > tail.length) {
    throw Exception('ZIP64 central directory locator not found');
  }

  final zip64EocdOffset = _readUint64Le(tail, locatorOffset + 8);
  await raf.setPosition(zip64EocdOffset);
  final header = Uint8List.fromList(await raf.read(56));
  if (header.length < 56 || _readUint32Le(header, 0) != 0x06064b50) {
    throw Exception('ZIP64 central directory record not found');
  }

  return _Zip64CentralDirectoryInfo(
    size: _readUint64Le(header, 40),
    offset: _readUint64Le(header, 48),
  );
}

_Zip64EntryInfo _readZip64EntryInfo(
  Uint8List centralDirectory,
  int extraStart,
  int extraLength, {
  required bool needsUncompressedSize,
  required bool needsCompressedSize,
  required bool needsLocalHeaderOffset,
}) {
  final extraEnd = extraStart + extraLength;
  var offset = extraStart;
  while (offset + 4 <= extraEnd && offset + 4 <= centralDirectory.length) {
    final headerId = _readUint16Le(centralDirectory, offset);
    final dataSize = _readUint16Le(centralDirectory, offset + 2);
    final dataStart = offset + 4;
    final dataEnd = dataStart + dataSize;
    if (dataEnd > extraEnd || dataEnd > centralDirectory.length) break;

    if (headerId == 0x0001) {
      int? uncompressedSize;
      int? compressedSize;
      int? localHeaderOffset;
      var cursor = dataStart;

      if (needsUncompressedSize && cursor + 8 <= dataEnd) {
        uncompressedSize = _readUint64Le(centralDirectory, cursor);
        cursor += 8;
      }
      if (needsCompressedSize && cursor + 8 <= dataEnd) {
        compressedSize = _readUint64Le(centralDirectory, cursor);
        cursor += 8;
      }
      if (needsLocalHeaderOffset && cursor + 8 <= dataEnd) {
        localHeaderOffset = _readUint64Le(centralDirectory, cursor);
      }

      return _Zip64EntryInfo(
        uncompressedSize: uncompressedSize,
        compressedSize: compressedSize,
        localHeaderOffset: localHeaderOffset,
      );
    }

    offset = dataEnd;
  }

  throw Exception('ZIP64 entry metadata not found');
}

Future<_ZipBackupIndex> _readZipBackupIndex(String zipPath) async {
  final file = File(zipPath);
  final length = await file.length();
  final tailLength = length < 66000 ? length : 66000;
  final tailStart = length - tailLength;

  final raf = await file.open(mode: FileMode.read);
  try {
    await raf.setPosition(tailStart);
    final tail = Uint8List.fromList(await raf.read(tailLength));

    var eocdOffset = -1;
    for (var i = tail.length - 22; i >= 0; i--) {
      if (_readUint32Le(tail, i) == 0x06054b50) {
        eocdOffset = i;
        break;
      }
    }
    if (eocdOffset < 0) {
      throw Exception('ZIP central directory not found');
    }

    var centralDirectorySize = _readUint32Le(tail, eocdOffset + 12);
    var centralDirectoryOffset = _readUint32Le(tail, eocdOffset + 16);
    if (centralDirectorySize == 0xffffffff ||
        centralDirectoryOffset == 0xffffffff) {
      final zip64 = await _readZip64CentralDirectoryInfo(
        raf: raf,
        tail: tail,
        eocdOffset: eocdOffset,
      );
      centralDirectorySize = zip64.size;
      centralDirectoryOffset = zip64.offset;
    }

    await raf.setPosition(centralDirectoryOffset);
    final centralDirectory = Uint8List.fromList(
      await raf.read(centralDirectorySize),
    );

    final entries = <String, _ZipBackupEntry>{};
    var offset = 0;
    while (offset + 46 <= centralDirectory.length) {
      final signature = _readUint32Le(centralDirectory, offset);
      if (signature != 0x02014b50) break;

      final compressionMethod = _readUint16Le(centralDirectory, offset + 10);
      var compressedSize = _readUint32Le(centralDirectory, offset + 20);
      var uncompressedSize = _readUint32Le(centralDirectory, offset + 24);
      final fileNameLength = _readUint16Le(centralDirectory, offset + 28);
      final extraLength = _readUint16Le(centralDirectory, offset + 30);
      final commentLength = _readUint16Le(centralDirectory, offset + 32);
      var localHeaderOffset = _readUint32Le(centralDirectory, offset + 42);

      final nameStart = offset + 46;
      final nameEnd = nameStart + fileNameLength;
      if (nameEnd > centralDirectory.length) break;

      final name = _normalizeZipName(
        utf8.decode(centralDirectory.sublist(nameStart, nameEnd)),
      );
      if (name.isNotEmpty) {
        if (uncompressedSize == 0xffffffff ||
            compressedSize == 0xffffffff ||
            localHeaderOffset == 0xffffffff) {
          final zip64 = _readZip64EntryInfo(
            centralDirectory,
            nameEnd,
            extraLength,
            needsUncompressedSize: uncompressedSize == 0xffffffff,
            needsCompressedSize: compressedSize == 0xffffffff,
            needsLocalHeaderOffset: localHeaderOffset == 0xffffffff,
          );
          uncompressedSize = zip64.uncompressedSize ?? uncompressedSize;
          compressedSize = zip64.compressedSize ?? compressedSize;
          localHeaderOffset = zip64.localHeaderOffset ?? localHeaderOffset;
        }

        entries[name] = _ZipBackupEntry(
          name: name,
          compressionMethod: compressionMethod,
          compressedSize: compressedSize,
          uncompressedSize: uncompressedSize,
          localHeaderOffset: localHeaderOffset,
          isDirectory: name.endsWith('/'),
        );
      }

      offset = nameEnd + extraLength + commentLength;
    }

    return _ZipBackupIndex(entries);
  } finally {
    await raf.close();
  }
}

Future<void> _extractZipBackupEntry({
  required String zipPath,
  required _ZipBackupEntry entry,
  required String outputPath,
}) async {
  if (entry.isDirectory) {
    await Directory(outputPath).create(recursive: true);
    return;
  }

  final file = File(zipPath);
  final raf = await file.open(mode: FileMode.read);
  late final int dataStart;
  try {
    await raf.setPosition(entry.localHeaderOffset);
    final header = Uint8List.fromList(await raf.read(30));
    if (header.length < 30 || _readUint32Le(header, 0) != 0x04034b50) {
      throw Exception('Invalid ZIP local header for ${entry.name}');
    }
    final fileNameLength = _readUint16Le(header, 26);
    final extraLength = _readUint16Le(header, 28);
    dataStart = entry.localHeaderOffset + 30 + fileNameLength + extraLength;
  } finally {
    await raf.close();
  }

  final output = File(outputPath);
  await output.parent.create(recursive: true);
  final sink = output.openWrite();
  try {
    final source = file.openRead(dataStart, dataStart + entry.compressedSize);
    if (entry.compressionMethod == ZipFile.zipCompressionStore) {
      await source.pipe(sink);
    } else if (entry.compressionMethod == ZipFile.zipCompressionDeflate) {
      await source.transform(ZLibCodec(raw: true).decoder).pipe(sink);
    } else {
      throw Exception(
        'Unsupported ZIP compression method ${entry.compressionMethod}',
      );
    }
  } catch (_) {
    await sink.close();
    rethrow;
  }
}

class _BackupEstimate {
  const _BackupEstimate({
    required this.contentBytes,
    required this.estimatedZipBytes,
    required this.includedFiles,
    required this.missingFiles,
  });

  final int contentBytes;
  final int estimatedZipBytes;
  final int includedFiles;
  final int missingFiles;
}

class _ManifestArrayStats {
  const _ManifestArrayStats({required this.totalObjects});

  final int totalObjects;
}

/// Gestiona: exportar e importar copias de seguridad de la librería.
class BackupRestoreController extends GetxController {
  // ============================
  // Estado Reactivo (UI)
  // ============================
  final RxBool isExporting = false.obs;
  final RxBool isImporting = false.obs;
  final RxDouble progress = 0.0.obs;
  final RxString currentOperation = ''.obs;

  Future<void> _yieldUi([int ms = 1]) async {
    await Future.delayed(Duration(milliseconds: ms));
  }

  Future<void> confirmExportLibrary() async {
    if (isExporting.value || isImporting.value) return;

    final includeInstrumentals = await _showExportOptionsDialog();
    if (includeInstrumentals == null) return;

    _showBusyDialog(
      title: 'Preparando respaldo',
      message: 'Calculando tamaño estimado del backup completo...',
      icon: Icons.calculate_rounded,
      accent: Colors.orange,
    );

    _BackupEstimate estimate;
    try {
      estimate = await _estimateFullBackup(
        includeInstrumentalVariants: includeInstrumentals,
      );
    } catch (e) {
      await _closeProgressDialog();
      Get.snackbar(
        'Copia de seguridad',
        'No se pudo calcular el tamaño estimado',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    await _closeProgressDialog();
    await _yieldUi(80);

    final estimateLabel = _formatBytes(estimate.estimatedZipBytes);
    final contentLabel = _formatBytes(estimate.contentBytes);
    final confirmed = await _showActionDialog(
      title: 'Respaldo completo',
      subtitle:
          'Incluye toda tu media offline (audio, video e imágenes), '
          'la configuración de pantalla de inicio y la librería. '
          'Los archivos se empaquetan sin comprimir (modo STORE) para mayor velocidad.',
      icon: Icons.archive_rounded,
      accent: Colors.orange,
      notes: [
        includeInstrumentals
            ? 'Se incluirán también variantes instrumentales.'
            : 'No se incluirán variantes instrumentales en este backup.',
        'Tamaño estimado: ~$estimateLabel (contenido detectado: $contentLabel).',
        'Archivos incluidos en la estimación: ${estimate.includedFiles}.',
        if (estimate.missingFiles > 0)
          'Archivos no encontrados (no se incluirán): ${estimate.missingFiles}.',
        'El empaquetado sin compresión es rápido pero genera ZIPs del mismo tamaño que los archivos originales.',
        'No cierres la app durante el proceso.',
      ],
      confirmText: 'Continuar',
    );

    if (confirmed == true) {
      await exportLibrary(includeInstrumentalVariants: includeInstrumentals);
    }
  }

  Future<void> confirmImportLibrary() async {
    if (isExporting.value || isImporting.value) return;

    final action = await _showImportDialog();
    if (action == null) return;
    await _yieldUi(80);

    final kind = action['action']?.trim();
    if (kind == 'pick') {
      await importLibrary();
      return;
    }

    if (kind == 'locate') {
      final reference = (action['value'] ?? '').trim();
      if (reference.isEmpty) return;

      _showBusyDialog(
        title: 'Localizando backup',
        message: 'Buscando el ZIP usando la ruta o código indicado...',
        icon: Icons.search_rounded,
        accent: Colors.teal,
      );

      final foundPath = await _locateBackupZipByReference(reference);
      await _closeProgressDialog();
      await _yieldUi(80);

      if (foundPath == null) {
        await _showResultDialog(
          title: 'No se encontró el backup',
          message:
              'No pude localizar el ZIP con ese código/ruta. Puedes usar "Seleccionar ZIP" para elegirlo manualmente.',
          icon: Icons.search_off_rounded,
          accent: Colors.orange,
          confirmText: 'Entendido',
        );
        return;
      }

      await importLibrary(zipPath: foundPath);
    }
  }

  Future<bool?> _showExportOptionsDialog() async {
    var includeInstrumentals = true;
    return Get.dialog<bool>(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Opciones de respaldo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: includeInstrumentals,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incluir variantes instrumentales'),
                  subtitle: const Text(
                    'Si se desactiva, se respaldan solo variantes normales.',
                  ),
                  onChanged: (value) {
                    setStateDialog(() {
                      includeInstrumentals = value ?? true;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back<bool?>(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: includeInstrumentals),
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      ),
      barrierDismissible: true,
    );
  }

  void _showProgressDialog(String title) {
    progress.value = 0.0;
    currentOperation.value = 'Iniciando...';
    final isExport = title.toLowerCase().contains('respaldo');
    final icon = isExport ? Icons.archive_rounded : Icons.restore_rounded;
    final accent = isExport ? Colors.orange : Colors.teal;
    Get.dialog(
      PopScope(
        canPop: false, // Prevenir que cierren el diálogo durante la operación
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final scheme = theme.colorScheme;
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Obx(() {
                  final raw = progress.value;
                  final hasProgress = raw > 0;
                  final value = raw.clamp(0.0, 1.0).toDouble();
                  final percent = (value * 100).round();

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasProgress
                                      ? '$percent% completado'
                                      : 'Preparando proceso...',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withOpacity(
                            .45,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: scheme.outlineVariant.withOpacity(.35),
                          ),
                        ),
                        child: Text(
                          currentOperation.value,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: hasProgress ? value : null,
                          backgroundColor: scheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No cierres la app mientras se procesa la operación.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  );
                }),
              );
            },
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _closeProgressDialog() async {
    if (Get.isDialogOpen ?? false) {
      Get.back();
      await _yieldUi(120);
    }
  }

  void _showBusyDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color accent,
  }) {
    Get.dialog(
      PopScope(
        canPop: false,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final scheme = theme.colorScheme;
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              backgroundColor: scheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<Map<String, String>?> _showImportDialog() async {
    var inputValue = '';

    return Get.dialog<Map<String, String>>(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            final media = MediaQuery.of(context);

            return AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: StatefulBuilder(
                builder: (context, setState) {
                  final hasInput = inputValue.trim().isNotEmpty;

                  void closeWith(Map<String, String>? result) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Get.back(result: result);
                  }

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: media.size.height * 0.82,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.restore_rounded,
                                  color: Colors.teal,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Restaurar respaldo',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Puedes seleccionar el ZIP manualmente o pegar la ruta/código de ubicación generado al exportar.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.teal.withOpacity(.20),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  minLines: 1,
                                  maxLines: 3,
                                  textInputAction: TextInputAction.done,
                                  onChanged: (value) {
                                    inputValue = value;
                                    setState(() {});
                                  },
                                  onSubmitted: (_) {
                                    if (!hasInput) return;
                                    closeWith({
                                      'action': 'locate',
                                      'value': inputValue.trim(),
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    labelText: 'Codigo o ruta del backup',
                                    hintText:
                                        'Ej: LFB:listenfy_backup_20260226_1030.zip',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Si el archivo se movió, usa el codigo (LFB:...) para intentar localizarlo.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => closeWith(null),
                                  child: const Text('Cancelar'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      closeWith(const {'action': 'pick'}),
                                  icon: const Icon(Icons.folder_open_rounded),
                                  label: const Text('Seleccionar ZIP'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: hasInput
                                  ? () => closeWith({
                                      'action': 'locate',
                                      'value': inputValue.trim(),
                                    })
                                  : null,
                              icon: const Icon(Icons.search_rounded),
                              label: const Text('Localizar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      barrierDismissible: true,
    );
  }

  Future<bool?> _showActionDialog({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required List<String> notes,
    required String confirmText,
  }) {
    return Get.dialog<bool>(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            final maxHeight = MediaQuery.of(context).size.height * 0.82;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withOpacity(.22)),
                      ),
                      child: Column(
                        children: notes
                            .map(
                              (note) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Icon(
                                        Icons.circle,
                                        size: 7,
                                        color: accent,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        note,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(height: 1.25),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Get.back(result: false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Get.back(result: true),
                            icon: Icon(icon, size: 18),
                            label: Text(confirmText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      barrierDismissible: true,
    );
  }

  Future<void> _showResultDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color accent,
    String? detailLabel,
    String? detailValue,
    String confirmText = 'Cerrar',
    String? cancelText,
    Future<void> Function()? onConfirm,
  }) async {
    final result = await Get.dialog<bool>(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            final maxHeight = MediaQuery.of(context).size.height * 0.82;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                    if ((detailValue ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withOpacity(
                            .45,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: scheme.outlineVariant.withOpacity(.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((detailLabel ?? '').trim().isNotEmpty) ...[
                              Text(
                                detailLabel!,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            SelectableText(
                              detailValue!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (cancelText != null) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Get.back(result: false),
                              child: Text(cancelText),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Get.back(result: true),
                            icon: Icon(icon, size: 18),
                            label: Text(confirmText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      barrierDismissible: true,
    );

    if (result == true && onConfirm != null) {
      await onConfirm();
    }
  }

  // ============================
  // 📤 EXPORTAR
  // ============================
  Future<void> exportLibrary({bool includeInstrumentalVariants = true}) async {
    if (isExporting.value || isImporting.value) return;

    try {
      final backupDir = await _resolveBackupDir();
      if (backupDir == null) return; // Usuario canceló la selección de carpeta

      // Esperar a que la transición de la Activity Nativa termine antes de abrir el Dialog
      await Future.delayed(const Duration(milliseconds: 300));

      isExporting.value = true;
      _showProgressDialog('Respaldo de Librería');
      // Dar tiempo a Flutter/Android para pintar el diálogo antes de trabajo pesado.
      await _yieldUi(50);
      currentOperation.value = 'Recolectando datos...';
      progress.value = 0.1;

      final libraryStore = Get.find<LocalLibraryStore>();
      final playlistStore = Get.find<PlaylistStore>();
      final artistStore = Get.find<ArtistStore>();
      final pillStore = Get.find<SourceThemePillStore>();
      final topicStore = Get.find<SourceThemeTopicStore>();
      final topicPlaylistStore = Get.find<SourceThemeTopicPlaylistStore>();

      final items = await libraryStore.readAll();
      final playlists = await playlistStore.readAll();
      final artists = await artistStore.readAll();
      final pills = await pillStore.readAll();
      final topics = await topicStore.readAll();
      final topicPlaylists = await topicPlaylistStore.readAll();

      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory(
        p.join(
          appDir.path,
          'backup_tmp_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      await tempDir.create(recursive: true);
      final filesDir = Directory(p.join(tempDir.path, 'files'));
      await filesDir.create(recursive: true);

      Future<String?> copyToBackup(String? absPath) async {
        final clean = absPath?.trim() ?? '';
        if (clean.isEmpty) return null;
        final src = File(clean);
        if (!await src.exists()) return null;

        final rel = _relativeBackupPath(appDir.path, clean);
        final dest = File(p.join(filesDir.path, rel));
        await dest.parent.create(recursive: true);
        await src.copy(dest.path);
        return rel;
      }

      final itemsJson = <Map<String, dynamic>>[];
      for (int i = 0; i < items.length; i++) {
        if (i % 10 == 0) {
          await _yieldUi();
        }
        currentOperation.value =
            'Procesando canciones (${i + 1}/${items.length})';
        progress.value = 0.1 + (0.4 * (i / items.length));

        final item = items[i];
        final data = Map<String, dynamic>.from(item.toJson());
        final thumbRel = await copyToBackup(item.thumbnailLocalPath);
        if (thumbRel != null) {
          data['thumbnailLocalPath'] = thumbRel;
        }

        final variants = (data['variants'] as List?) ?? const [];
        final updatedVariants = <Map<String, dynamic>>[];
        for (final raw in variants) {
          if (raw is! Map) continue;
          final v = Map<String, dynamic>.from(raw);
          if (!includeInstrumentalVariants && _isInstrumentalVariantMap(v)) {
            continue;
          }
          final localPath = (v['localPath'] as String?)?.trim();
          if (localPath != null && localPath.isNotEmpty) {
            final rel = await copyToBackup(localPath);
            if (rel != null) {
              v['localPath'] = rel;
            }
          }
          updatedVariants.add(v);
        }
        data['variants'] = updatedVariants;
        itemsJson.add(data);
      }

      currentOperation.value = 'Procesando Playlists & Fuentes...';
      progress.value = 0.6;

      final playlistsJson = <Map<String, dynamic>>[];
      for (final playlist in playlists) {
        final data = Map<String, dynamic>.from(playlist.toJson());
        final coverRel = await copyToBackup(playlist.coverLocalPath);
        if (coverRel != null) {
          data['coverLocalPath'] = coverRel;
        }
        playlistsJson.add(data);
      }

      final artistsJson = <Map<String, dynamic>>[];
      for (final artist in artists) {
        final data = Map<String, dynamic>.from(artist.toJson());
        final thumbRel = await copyToBackup(artist.thumbnailLocalPath);
        if (thumbRel != null) {
          data['thumbnailLocalPath'] = thumbRel;
        }
        artistsJson.add(data);
      }

      final topicsJson = <Map<String, dynamic>>[];
      for (final topic in topics) {
        final data = Map<String, dynamic>.from(topic.toJson());
        final coverRel = await copyToBackup(topic.coverLocalPath);
        if (coverRel != null) {
          data['coverLocalPath'] = coverRel;
        }
        topicsJson.add(data);
      }

      final topicPlaylistsJson = <Map<String, dynamic>>[];
      for (final playlist in topicPlaylists) {
        final data = Map<String, dynamic>.from(playlist.toJson());
        final coverRel = await copyToBackup(playlist.coverLocalPath);
        if (coverRel != null) {
          data['coverLocalPath'] = coverRel;
        }
        topicPlaylistsJson.add(data);
      }

      final capturesJson = <Map<String, dynamic>>[];
      final captureStore = CaptureGalleryStore(Get.find<GetStorage>());
      final captures = await captureStore.listCaptures();
      for (final capture in captures) {
        final rel = await copyToBackup(capture.path);
        if (rel == null) continue;
        capturesJson.add({
          'path': rel,
          'name': capture.name,
          'modifiedAt': capture.modifiedAt.toIso8601String(),
          'size': capture.size,
          'tags': capture.tags,
          if (capture.sourceTitle != null) 'sourceTitle': capture.sourceTitle,
          if (capture.sourceId != null) 'sourceId': capture.sourceId,
        });
      }
      final captureTagCollectionsJson = <Map<String, dynamic>>[];
      final captureTagCollections = captureStore.tagCollections(
        fallbackColor: 0xFF7C8BA1,
      );
      for (final entry in captureTagCollections.entries) {
        final data = Map<String, dynamic>.from(entry.value.toJson());
        final thumbRel = await copyToBackup(entry.value.thumbnailPath);
        if (thumbRel != null) {
          data['thumbnailPath'] = thumbRel;
        }
        captureTagCollectionsJson.add({'key': entry.key, 'data': data});
      }

      final settingsController = Get.find<SettingsController>();
      final backgroundImageRels = <String>[];
      String? activeBackgroundImageRel;
      for (final imagePath in settingsController.appBackgroundImagePaths) {
        final rel = await copyToBackup(imagePath);
        if (rel == null) continue;
        backgroundImageRels.add(rel);
        if (imagePath == settingsController.appBackgroundImagePath.value) {
          activeBackgroundImageRel = rel;
        }
      }
      final appearancePayload = <String, dynamic>{
        'appBackgroundImagePaths': backgroundImageRels,
        if (activeBackgroundImageRel != null)
          'appBackgroundImagePath': activeBackgroundImageRel,
        'smartBackgroundCarouselEnabled':
            settingsController.smartBackgroundCarouselEnabled.value,
        'orderedBackgroundCarouselEnabled':
            settingsController.orderedBackgroundCarouselEnabled.value,
      };

      currentOperation.value = 'Empaquetando archivo ZIP (sin comprimir)...';
      progress.value = 0.8;

      Map<String, dynamic> recommendationPayload = const {};
      if (Get.isRegistered<RecommendationStore>()) {
        recommendationPayload = await Get.find<RecommendationStore>()
            .exportBackupPayload();
      }
      Map<String, dynamic> recommendationFeedbackPayload = const {};
      if (Get.isRegistered<RecommendationFeedbackStore>()) {
        recommendationFeedbackPayload =
            await Get.find<RecommendationFeedbackStore>().exportBackupPayload();
      }

      // ── Configuración de widgets de pantalla de inicio ───────────────────
      final homeStorage = GetStorage();
      const homeWidgetOrderKey = 'home_widget_order';
      const homeWidgetEnabledKey = 'home_widget_enabled';
      const homeWidgetLayoutsKey = 'home_widget_layouts';
      const homeCustomSectionsKey = 'home_custom_sections';
      const videoHomeWidgetOrderKey = 'video_home_widget_order';
      const videoHomeWidgetEnabledKey = 'video_home_widget_enabled';
      const videoHomeCustomSectionsKey = 'video_home_custom_sections';

      final homeLayoutPayload = <String, dynamic>{
        homeWidgetOrderKey:
            homeStorage.read<List>(homeWidgetOrderKey) ?? const [],
        homeWidgetEnabledKey:
            homeStorage.read<List>(homeWidgetEnabledKey) ?? const [],
        homeWidgetLayoutsKey:
            homeStorage.read<Map>(homeWidgetLayoutsKey) ?? const {},
        homeCustomSectionsKey:
            homeStorage.read<List>(homeCustomSectionsKey) ?? const [],
        videoHomeWidgetOrderKey:
            homeStorage.read<List>(videoHomeWidgetOrderKey) ?? const [],
        videoHomeWidgetEnabledKey:
            homeStorage.read<List>(videoHomeWidgetEnabledKey) ?? const [],
        videoHomeCustomSectionsKey:
            homeStorage.read<List>(videoHomeCustomSectionsKey) ?? const [],
      };
      // ─────────────────────────────────────────────────────────────────────

      final manifest = <String, dynamic>{
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'backupOptions': <String, dynamic>{
          'includeInstrumentalVariants': includeInstrumentalVariants,
        },
        'items': itemsJson,
        'playlists': playlistsJson,
        'artists': artistsJson,
        'sourceThemePills': pills.map((e) => e.toJson()).toList(),
        'sourceThemeTopics': topicsJson,
        'sourceThemeTopicPlaylists': topicPlaylistsJson,
        'captureGallery': capturesJson,
        'captureTagCollections': captureTagCollectionsJson,
        'homeLayout': homeLayoutPayload,
        'appearance': appearancePayload,
        ...recommendationPayload,
        ...recommendationFeedbackPayload,
      };

      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);
      final appearanceFile = File(p.join(tempDir.path, 'appearance.json'));
      await appearanceFile.writeAsString(
        jsonEncode(appearancePayload),
        flush: true,
      );

      await backupDir.create(recursive: true);
      final zipPath = p.join(backupDir.path, _backupFileName());

      // La compresión ZIP puede bloquear el hilo UI por varios segundos en MIUI.
      await compute(_createZipIsolate, {
        'sourceDir': tempDir.path,
        'zipPath': zipPath,
      });

      currentOperation.value = 'Limpiando archivos temporales...';
      progress.value = 0.95;

      await tempDir.delete(recursive: true);

      await _closeProgressDialog();
      await _yieldUi(80);
      final locationCode = _backupLocationCode(zipPath);

      await _showResultDialog(
        title: 'Respaldo completo creado',
        message:
            'Se guardó la copia con tu librería y toda la media offline. Guarda la ruta o el codigo LFB para localizar el ZIP después.',
        icon: Icons.task_alt_rounded,
        accent: Colors.green,
        detailLabel: 'Ruta / codigo de ubicacion',
        detailValue: 'Ruta:\n$zipPath\n\nCodigo:\n$locationCode',
        confirmText: 'Copiar ruta',
        cancelText: 'Cerrar',
        onConfirm: () async {
          await Clipboard.setData(ClipboardData(text: zipPath));
          Get.snackbar(
            'Copia de seguridad',
            'Ruta copiada al portapapeles',
            snackPosition: SnackPosition.BOTTOM,
          );
        },
      );
    } catch (e) {
      await _closeProgressDialog();
      Get.snackbar(
        'Copia de seguridad',
        'No se pudo exportar',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('exportLibrary error: $e');
    } finally {
      isExporting.value = false;
      progress.value = 0.0;
    }
  }

  // ============================
  // 📥 IMPORTAR
  // ============================
  Future<void> importLibrary({String? zipPath}) async {
    if (isExporting.value || isImporting.value) return;

    try {
      String path = (zipPath ?? '').trim();
      if (path.isEmpty) {
        FilePickerResult? res;
        try {
          res = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: const ['zip'],
          );
        } catch (pickErr) {
          print('Error al abrir FilePicker: $pickErr');
          return;
        }

        final file = res?.files.first;
        final pickedPath = file?.path?.trim() ?? '';
        if (pickedPath.isEmpty) return;
        path = pickedPath;
      }

      final zipFile = File(path);
      if (!await zipFile.exists()) {
        Get.snackbar(
          'Copia de seguridad',
          'No se encontró el archivo ZIP indicado',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Esperar a que la transición de la Activity Nativa termine antes de abrir el Dialog
      // Esto previene el clásico crash "fail in deliverResultsIfNeeded" en Android (MIUI).
      await Future.delayed(const Duration(milliseconds: 300));

      isImporting.value = true;
      _showProgressDialog('Restaurando Librería');
      // Permite que el diálogo llegue a pantalla antes de empezar la restauración.
      await _yieldUi(50);
      currentOperation.value = 'Descomprimiendo backup...';
      progress.value = 0.1;

      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory(
        p.join(
          appDir.path,
          'backup_import_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      await tempDir.create(recursive: true);

      currentOperation.value = 'Leyendo indice del backup...';
      progress.value = 0.15;

      final zipIndex = await _readZipBackupIndex(path);
      final manifestEntry = zipIndex.find('manifest.json');
      if (manifestEntry == null) {
        throw Exception('Manifest not found');
      }

      currentOperation.value = 'Extrayendo manifiesto...';
      await _extractZipBackupEntry(
        zipPath: path,
        entry: manifestEntry,
        outputPath: p.join(tempDir.path, 'manifest.json'),
      );

      progress.value = 0.3;

      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw Exception('Manifest not found');
      }

      currentOperation.value = 'Leyendo manifiesto...';
      progress.value = 0.3;

      final manifestLength = await manifestFile.length();
      final useStreamingManifest = manifestLength > 8 * 1024 * 1024;
      Map<String, dynamic>? manifest;
      if (useStreamingManifest) {
        currentOperation.value = 'Leyendo manifiesto grande por partes...';
      } else {
        final manifestRaw = await manifestFile.readAsString();
        manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
      }

      String? resolveRel(String? rel) {
        final clean = rel?.trim() ?? '';
        if (clean.isEmpty) return null;
        return p.join(appDir.path, clean);
      }

      Future<void> restoreFile(String? rel) async {
        final clean = rel?.trim() ?? '';
        if (clean.isEmpty) return;
        final entry = zipIndex.find(p.posix.join('files', clean));
        if (entry == null) return;
        final dest = File(p.join(appDir.path, clean));
        await _extractZipBackupEntry(
          zipPath: path,
          entry: entry,
          outputPath: dest.path,
        );
      }

      Map<String, dynamic>? appearancePayload;
      if (!useStreamingManifest && manifest?['appearance'] is Map) {
        appearancePayload = Map<String, dynamic>.from(
          manifest!['appearance'] as Map,
        );
      } else {
        final appearanceEntry = zipIndex.find('appearance.json');
        if (appearanceEntry != null) {
          final appearanceFile = File(p.join(tempDir.path, 'appearance.json'));
          await _extractZipBackupEntry(
            zipPath: path,
            entry: appearanceEntry,
            outputPath: appearanceFile.path,
          );
          final raw = jsonDecode(await appearanceFile.readAsString());
          if (raw is Map) {
            appearancePayload = Map<String, dynamic>.from(raw);
          }
        }
      }
      if (appearancePayload != null && Get.isRegistered<SettingsController>()) {
        final backgroundImageRels =
            (appearancePayload['appBackgroundImagePaths'] as List?)
                ?.map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toList() ??
            <String>[];
        final legacyBackgroundImageRel =
            appearancePayload['appBackgroundImagePath']?.toString().trim();
        if (backgroundImageRels.isEmpty &&
            legacyBackgroundImageRel != null &&
            legacyBackgroundImageRel.isNotEmpty) {
          backgroundImageRels.add(legacyBackgroundImageRel);
        }

        final restoredBackgroundPaths = <String>[];
        for (final rel in backgroundImageRels) {
          await restoreFile(rel);
          final restoredPath = resolveRel(rel);
          if (restoredPath != null) restoredBackgroundPaths.add(restoredPath);
        }
        final restoredActivePath =
            legacyBackgroundImageRel == null || legacyBackgroundImageRel.isEmpty
            ? null
            : resolveRel(legacyBackgroundImageRel);
        await Get.find<SettingsController>().restoreAppBackgroundImages(
          restoredBackgroundPaths,
          activePath: restoredActivePath,
        );
        final settingsController = Get.find<SettingsController>();
        await settingsController.setOrderedBackgroundCarouselEnabled(
          appearancePayload['orderedBackgroundCarouselEnabled'] == true,
        );
        await settingsController.setSmartBackgroundCarouselEnabled(
          appearancePayload['smartBackgroundCarouselEnabled'] == true,
        );
      }

      currentOperation.value = 'Restaurando canciones...';
      progress.value = 0.4;

      final libraryStore = Get.find<LocalLibraryStore>();
      var restoredItems = 0;
      final itemsToRestore = <MediaItem>[];
      Future<void> restoreItem(Map<String, dynamic> data, int i) async {
        if (i % 10 == 0) {
          await _yieldUi();
          currentOperation.value = 'Restaurando canciones (${i + 1})';
          progress.value = (0.4 + (0.3 * ((i % 500) / 500))).clamp(0.4, 0.7);
        }

        final thumbRel = (data['thumbnailLocalPath'] as String?)?.trim();
        if (thumbRel != null && thumbRel.isNotEmpty) {
          await restoreFile(thumbRel);
          data['thumbnailLocalPath'] = resolveRel(thumbRel);
        }

        final variants = (data['variants'] as List?) ?? const [];
        final updatedVariants = <Map<String, dynamic>>[];
        for (final vRaw in variants) {
          if (vRaw is! Map) continue;
          final v = Map<String, dynamic>.from(vRaw);
          final localRel = (v['localPath'] as String?)?.trim();
          if (localRel != null && localRel.isNotEmpty) {
            await restoreFile(localRel);
            v['localPath'] = resolveRel(localRel);
          }
          updatedVariants.add(v);
        }
        data['variants'] = updatedVariants;

        final item = MediaItem.fromJson(data);
        itemsToRestore.add(item);
        restoredItems++;
      }

      if (useStreamingManifest) {
        await _forEachManifestObject(
          manifestFile,
          'items',
          (data, index) => restoreItem(data, index),
        );
      } else {
        final itemsRaw = (manifest!['items'] as List?) ?? const [];
        for (int i = 0; i < itemsRaw.length; i++) {
          final raw = itemsRaw[i];
          if (raw is! Map) continue;
          await restoreItem(Map<String, dynamic>.from(raw), i);
        }
      }
      currentOperation.value = 'Guardando canciones restauradas...';
      await libraryStore.upsertAll(itemsToRestore);
      itemsToRestore.clear();

      currentOperation.value = 'Restaurando Playlists & Artistas...';
      progress.value = 0.75;

      final playlistStore = Get.find<PlaylistStore>();
      final playlistsToRestore = <Playlist>[];
      Future<void> restorePlaylist(Map<String, dynamic> data, int index) async {
        final coverRel = (data['coverLocalPath'] as String?)?.trim();
        if (coverRel != null && coverRel.isNotEmpty) {
          await restoreFile(coverRel);
          data['coverLocalPath'] = resolveRel(coverRel);
        }
        playlistsToRestore.add(Playlist.fromJson(data));
      }

      if (useStreamingManifest) {
        await _forEachManifestObject(
          manifestFile,
          'playlists',
          restorePlaylist,
        );
      } else {
        final playlistsRaw = (manifest!['playlists'] as List?) ?? const [];
        for (var i = 0; i < playlistsRaw.length; i++) {
          final raw = playlistsRaw[i];
          if (raw is! Map) continue;
          await restorePlaylist(Map<String, dynamic>.from(raw), i);
        }
      }
      await playlistStore.upsertAll(playlistsToRestore);
      playlistsToRestore.clear();

      final artistStore = Get.find<ArtistStore>();
      final artistsToRestore = <ArtistProfile>[];
      Future<void> restoreArtist(Map<String, dynamic> data, int index) async {
        final thumbRel = (data['thumbnailLocalPath'] as String?)?.trim();
        if (thumbRel != null && thumbRel.isNotEmpty) {
          await restoreFile(thumbRel);
          data['thumbnailLocalPath'] = resolveRel(thumbRel);
        }
        artistsToRestore.add(ArtistProfile.fromJson(data));
      }

      if (useStreamingManifest) {
        await _forEachManifestObject(manifestFile, 'artists', restoreArtist);
      } else {
        final artistsRaw = (manifest!['artists'] as List?) ?? const [];
        for (var i = 0; i < artistsRaw.length; i++) {
          final raw = artistsRaw[i];
          if (raw is! Map) continue;
          await restoreArtist(Map<String, dynamic>.from(raw), i);
        }
      }
      await artistStore.upsertAll(artistsToRestore);
      artistsToRestore.clear();

      currentOperation.value = 'Restaurando Fuentes...';
      progress.value = 0.85;

      final pillStore = Get.find<SourceThemePillStore>();
      final pillsToRestore = <SourceThemePill>[];
      Future<void> restorePill(Map<String, dynamic> data, int index) async {
        pillsToRestore.add(SourceThemePill.fromJson(data));
      }

      if (useStreamingManifest) {
        await _forEachManifestObject(
          manifestFile,
          'sourceThemePills',
          restorePill,
        );
      } else {
        final pillsRaw = (manifest!['sourceThemePills'] as List?) ?? const [];
        for (var i = 0; i < pillsRaw.length; i++) {
          final raw = pillsRaw[i];
          if (raw is! Map) continue;
          await restorePill(Map<String, dynamic>.from(raw), i);
        }
      }
      await pillStore.upsertAll(pillsToRestore);
      pillsToRestore.clear();

      final topicStore = Get.find<SourceThemeTopicStore>();
      final topicsToRestore = <SourceThemeTopic>[];
      Future<void> restoreTopic(Map<String, dynamic> data, int index) async {
        final coverRel = (data['coverLocalPath'] as String?)?.trim();
        if (coverRel != null && coverRel.isNotEmpty) {
          await restoreFile(coverRel);
          data['coverLocalPath'] = resolveRel(coverRel);
        }
        topicsToRestore.add(SourceThemeTopic.fromJson(data));
      }

      if (useStreamingManifest) {
        await _forEachManifestObject(
          manifestFile,
          'sourceThemeTopics',
          restoreTopic,
        );
      } else {
        final topicsRaw = (manifest!['sourceThemeTopics'] as List?) ?? const [];
        for (var i = 0; i < topicsRaw.length; i++) {
          final raw = topicsRaw[i];
          if (raw is! Map) continue;
          await restoreTopic(Map<String, dynamic>.from(raw), i);
        }
      }
      await topicStore.upsertAll(topicsToRestore);
      topicsToRestore.clear();

      final topicPlaylistStore = Get.find<SourceThemeTopicPlaylistStore>();
      final topicPlaylistsToRestore = <SourceThemeTopicPlaylist>[];
      Future<void> restoreTopicPlaylist(
        Map<String, dynamic> data,
        int index,
      ) async {
        final coverRel = (data['coverLocalPath'] as String?)?.trim();
        if (coverRel != null && coverRel.isNotEmpty) {
          await restoreFile(coverRel);
          data['coverLocalPath'] = resolveRel(coverRel);
        }
        topicPlaylistsToRestore.add(SourceThemeTopicPlaylist.fromJson(data));
      }

      if (useStreamingManifest) {
        await _forEachManifestObject(
          manifestFile,
          'sourceThemeTopicPlaylists',
          restoreTopicPlaylist,
        );
      } else {
        final topicPlaylistsRaw =
            (manifest!['sourceThemeTopicPlaylists'] as List?) ?? const [];
        for (var i = 0; i < topicPlaylistsRaw.length; i++) {
          final raw = topicPlaylistsRaw[i];
          if (raw is! Map) continue;
          await restoreTopicPlaylist(Map<String, dynamic>.from(raw), i);
        }
      }
      await topicPlaylistStore.upsertAll(topicPlaylistsToRestore);
      topicPlaylistsToRestore.clear();

      currentOperation.value = 'Restaurando capturas...';
      final captureStore = CaptureGalleryStore(Get.find<GetStorage>());
      Future<void> restoreCapture(Map<String, dynamic> data, int index) async {
        final rel = (data['path'] as String?)?.trim();
        if (rel == null || rel.isEmpty) return;
        await restoreFile(rel);
        final restoredPath = resolveRel(rel);
        if (restoredPath == null) return;
        final modifiedAt = DateTime.tryParse(
          data['modifiedAt']?.toString() ?? '',
        );
        if (modifiedAt != null) {
          final file = File(restoredPath);
          if (await file.exists()) {
            await file.setLastModified(modifiedAt);
          }
        }
        final tags =
            (data['tags'] as List?)?.map((e) => e.toString()) ??
            const Iterable<String>.empty();
        await captureStore.restoreTags(restoredPath, tags);
        await captureStore.setSource(
          restoredPath,
          title: data['sourceTitle']?.toString(),
          sourceId: data['sourceId']?.toString(),
        );
      }

      if (useStreamingManifest) {
        await _forEachManifestObject(
          manifestFile,
          'captureGallery',
          restoreCapture,
        );
      } else {
        final capturesRaw = (manifest!['captureGallery'] as List?) ?? const [];
        for (var i = 0; i < capturesRaw.length; i++) {
          final raw = capturesRaw[i];
          if (raw is! Map) continue;
          await restoreCapture(Map<String, dynamic>.from(raw), i);
        }
      }

      Future<void> restoreCaptureTagCollections(
        Map<String, dynamic> nextCollections,
      ) async {
        await captureStore.restoreTagCollections(nextCollections);
      }

      Future<void> restoreCaptureTagCollection(
        String rawKey,
        Map<dynamic, dynamic> rawData,
      ) async {
        final key = rawKey.trim().toLowerCase();
        if (key.isEmpty) return;
        final data = Map<String, dynamic>.from(rawData);
        final thumbRel = data['thumbnailPath']?.toString().trim();
        if (thumbRel != null && thumbRel.isNotEmpty) {
          await restoreFile(thumbRel);
          data['thumbnailPath'] = resolveRel(thumbRel);
        }
        await restoreCaptureTagCollections({key: data});
      }

      if (!useStreamingManifest && manifest != null) {
        final rawCollections = manifest['captureTagCollections'];
        if (rawCollections is List) {
          for (final raw in rawCollections) {
            if (raw is! Map) continue;
            final key = raw['key']?.toString();
            final data = raw['data'];
            if (key == null || data is! Map) continue;
            await restoreCaptureTagCollection(key, data);
          }
        } else if (rawCollections is Map) {
          for (final entry in rawCollections.entries) {
            final value = entry.value;
            if (value is! Map) continue;
            await restoreCaptureTagCollection(entry.key.toString(), value);
          }
        }
      } else {
        await _forEachManifestObject(manifestFile, 'captureTagCollections', (
          data,
          index,
        ) async {
          final key = data['key']?.toString();
          final value = data['data'];
          if (key == null || value is! Map) return;
          await restoreCaptureTagCollection(key, value);
        });
      }

      if (!useStreamingManifest && manifest != null) {
        if (Get.isRegistered<RecommendationStore>()) {
          await Get.find<RecommendationStore>().restoreBackupPayload(manifest);
          if (Get.isRegistered<RecommendationEngine>()) {
            await Get.find<RecommendationEngine>().reloadFromStore();
          }
        }
        if (Get.isRegistered<RecommendationFeedbackStore>()) {
          await Get.find<RecommendationFeedbackStore>().restoreBackupPayload(
            manifest,
          );
          if (Get.isRegistered<RecommendationFeedbackService>()) {
            await Get.find<RecommendationFeedbackService>().reloadFromStore();
          }
        }

        // ── Restaurar configuración de widgets de pantalla de inicio ─────────
        final rawHomeLayout = manifest['homeLayout'];
        if (rawHomeLayout is Map) {
          final GetStorage homeStorage = GetStorage();
          const homeWidgetOrderKey = 'home_widget_order';
          const homeWidgetEnabledKey = 'home_widget_enabled';
          const homeWidgetLayoutsKey = 'home_widget_layouts';
          const homeCustomSectionsKey = 'home_custom_sections';
          const videoHomeWidgetOrderKey = 'video_home_widget_order';
          const videoHomeWidgetEnabledKey = 'video_home_widget_enabled';
          const videoHomeCustomSectionsKey = 'video_home_custom_sections';

          final orderRaw = rawHomeLayout[homeWidgetOrderKey];
          if (orderRaw is List && orderRaw.isNotEmpty) {
            await homeStorage.write(homeWidgetOrderKey, orderRaw);
          }
          final enabledRaw = rawHomeLayout[homeWidgetEnabledKey];
          if (enabledRaw is List && enabledRaw.isNotEmpty) {
            await homeStorage.write(homeWidgetEnabledKey, enabledRaw);
          }
          final layoutsRaw = rawHomeLayout[homeWidgetLayoutsKey];
          if (layoutsRaw is Map && layoutsRaw.isNotEmpty) {
            await homeStorage.write(homeWidgetLayoutsKey, layoutsRaw);
          }
          final customRaw = rawHomeLayout[homeCustomSectionsKey];
          if (customRaw is List && customRaw.isNotEmpty) {
            await homeStorage.write(homeCustomSectionsKey, customRaw);
          }
          final videoOrderRaw = rawHomeLayout[videoHomeWidgetOrderKey];
          if (videoOrderRaw is List) {
            await homeStorage.write(videoHomeWidgetOrderKey, videoOrderRaw);
          }
          final videoEnabledRaw = rawHomeLayout[videoHomeWidgetEnabledKey];
          if (videoEnabledRaw is List) {
            await homeStorage.write(videoHomeWidgetEnabledKey, videoEnabledRaw);
          }
          final videoCustomRaw = rawHomeLayout[videoHomeCustomSectionsKey];
          if (videoCustomRaw is List) {
            await homeStorage.write(videoHomeCustomSectionsKey, videoCustomRaw);
          }
        }
        // ─────────────────────────────────────────────────────────────────────
      } else {
        debugPrint(
          'Backup import restored $restoredItems items using streaming manifest mode.',
        );
      }

      currentOperation.value =
          'Limpiando temporales y actualizando interfaz...';
      progress.value = 0.95;

      await tempDir.delete(recursive: true);

      if (Get.isRegistered<DownloadsController>()) {
        await Get.find<DownloadsController>().load();
      }
      if (Get.isRegistered<HomeController>()) {
        // 1) Primero forzamos que el controller relea el layout del storage
        //    (orden, widgets habilitados, layouts, secciones personalizadas).
        //    Si esto se omite, el controller mantiene su estado en memoria y
        //    la configuraci\u00f3n restaurada no se ve hasta reiniciar la app.
        Get.find<HomeController>().reloadLayoutFromStorage();
        // 2) Luego recargamos los datos de media.
        await Get.find<HomeController>().loadHome();
      }
      if (Get.isRegistered<ArtistsController>()) {
        await Get.find<ArtistsController>().load();
      }
      if (Get.isRegistered<PlaylistsController>()) {
        await Get.find<PlaylistsController>().load();
      }
      if (Get.isRegistered<SourcesController>()) {
        await Get.find<SourcesController>().refreshAll();
      }

      await _closeProgressDialog();
      await _yieldUi(80);

      await _showResultDialog(
        title: 'Importación completada',
        message:
            'La librería y los archivos offline se restauraron correctamente. Ya puedes usar tu contenido sin conexión.',
        icon: Icons.task_alt_rounded,
        accent: Colors.green,
        confirmText: 'Entendido',
      );
    } catch (e) {
      await _closeProgressDialog();
      Get.snackbar(
        'Copia de seguridad',
        'No se pudo importar',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('importLibrary error: $e');
    } finally {
      isImporting.value = false;
      progress.value = 0.0;
    }
  }

  // ============================
  // 🧰 HELPERS
  // ============================
  Future<_ManifestArrayStats> _forEachManifestObject(
    File manifestFile,
    String key,
    Future<void> Function(Map<String, dynamic> data, int index) onObject,
  ) async {
    final keyPattern = '"$key"';
    var buffer = '';
    var foundKey = false;
    var inArray = false;
    var inString = false;
    var escaped = false;
    var depth = 0;
    var objectBuffer = StringBuffer();
    var objectIndex = 0;

    await for (final chunk in manifestFile.openRead().transform(
      const Utf8Decoder(),
    )) {
      buffer += chunk;
      var i = 0;

      while (i < buffer.length) {
        if (!foundKey) {
          final idx = buffer.indexOf(keyPattern, i);
          if (idx < 0) {
            final keep = keyPattern.length - 1;
            buffer = buffer.length > keep
                ? buffer.substring(buffer.length - keep)
                : buffer;
            i = buffer.length;
            continue;
          }
          foundKey = true;
          i = idx + keyPattern.length;
        }

        if (!inArray) {
          final ch = buffer[i];
          if (ch == '[') {
            inArray = true;
          }
          i++;
          continue;
        }

        final ch = buffer[i];
        if (depth == 0) {
          if (ch == ']') {
            return _ManifestArrayStats(totalObjects: objectIndex);
          }
          if (ch == '{') {
            depth = 1;
            objectBuffer = StringBuffer()..write(ch);
            inString = false;
            escaped = false;
          }
          i++;
          continue;
        }

        objectBuffer.write(ch);
        if (inString) {
          if (escaped) {
            escaped = false;
          } else if (ch == r'\') {
            escaped = true;
          } else if (ch == '"') {
            inString = false;
          }
        } else if (ch == '"') {
          inString = true;
        } else if (ch == '{') {
          depth++;
        } else if (ch == '}') {
          depth--;
          if (depth == 0) {
            final decoded = jsonDecode(objectBuffer.toString());
            if (decoded is Map) {
              await onObject(Map<String, dynamic>.from(decoded), objectIndex);
              objectIndex++;
            }
            objectBuffer = StringBuffer();
          }
        }
        i++;
      }

      if (foundKey && inArray && depth > 0) {
        buffer = '';
      } else if (foundKey) {
        buffer = '';
      }
    }

    return _ManifestArrayStats(totalObjects: objectIndex);
  }

  Future<_BackupEstimate> _estimateFullBackup({
    required bool includeInstrumentalVariants,
  }) async {
    final libraryStore = Get.find<LocalLibraryStore>();
    final playlistStore = Get.find<PlaylistStore>();
    final artistStore = Get.find<ArtistStore>();
    final topicStore = Get.find<SourceThemeTopicStore>();
    final topicPlaylistStore = Get.find<SourceThemeTopicPlaylistStore>();

    final items = await libraryStore.readAll();
    final playlists = await playlistStore.readAll();
    final artists = await artistStore.readAll();
    final topics = await topicStore.readAll();
    final topicPlaylists = await topicPlaylistStore.readAll();

    final paths = <String>{};

    void addPath(String? rawPath) {
      final clean = rawPath?.trim() ?? '';
      if (clean.isEmpty) return;
      paths.add(p.normalize(clean));
    }

    for (final item in items) {
      addPath(item.thumbnailLocalPath);
      for (final v in item.variants) {
        if (!includeInstrumentalVariants && v.isInstrumental) {
          continue;
        }
        addPath(v.localPath);
      }
    }

    for (final playlist in playlists) {
      addPath(playlist.coverLocalPath);
    }

    for (final artist in artists) {
      addPath(artist.thumbnailLocalPath);
    }

    for (final topic in topics) {
      addPath(topic.coverLocalPath);
    }

    for (final topicPlaylist in topicPlaylists) {
      addPath(topicPlaylist.coverLocalPath);
    }

    int contentBytes = 0;
    int includedFiles = 0;
    int missingFiles = 0;

    final pathList = paths.toList(growable: false);
    for (var i = 0; i < pathList.length; i++) {
      if (i % 25 == 0) {
        await _yieldUi();
      }

      final file = File(pathList[i]);
      try {
        if (!await file.exists()) {
          missingFiles++;
          continue;
        }

        final size = await file.length();
        if (size > 0) {
          contentBytes += size;
        }
        includedFiles++;
      } catch (_) {
        missingFiles++;
      }
    }

    // En modo STORE el ZIP resultante tiene prácticamente el mismo tamaño que
    // el contenido original (sin compresión), más overhead de cabeceras (~300 B
    // por archivo). Usamos eso como estimación para que el diálogo sea preciso.
    final estimatedZipBytes =
        contentBytes + (1024 * 1024) + (includedFiles * 300);

    return _BackupEstimate(
      contentBytes: contentBytes,
      estimatedZipBytes: estimatedZipBytes,
      includedFiles: includedFiles,
      missingFiles: missingFiles,
    );
  }

  bool _isInstrumentalVariantMap(Map<String, dynamic> variantJson) {
    final role = (variantJson['role'] as String?)?.trim().toLowerCase() ?? '';
    if (role == 'instrumental' || role == 'inst') {
      return true;
    }
    final fileName =
        (variantJson['fileName'] as String?)?.trim().toLowerCase() ?? '';
    final localPath =
        (variantJson['localPath'] as String?)?.trim().toLowerCase() ?? '';
    return fileName.contains('_inst') ||
        fileName.contains('instrumental') ||
        localPath.contains('_inst') ||
        localPath.contains('/instrumental');
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final decimals = unitIndex <= 1 ? 0 : (value >= 100 ? 0 : 1);
    return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }

  String _backupLocationCode(String zipPath) {
    return 'LFB:${p.basename(zipPath)}';
  }

  Future<String?> _locateBackupZipByReference(String reference) async {
    final normalizedRef = _normalizeBackupReference(reference);
    if (normalizedRef.isEmpty) return null;

    if (normalizedRef.startsWith('file://')) {
      final uri = Uri.tryParse(normalizedRef);
      if (uri != null) {
        final filePath = uri.toFilePath();
        if (filePath.trim().isNotEmpty && await File(filePath).exists()) {
          return filePath;
        }
      }
    }

    final exactPath = normalizedRef;
    if (await File(exactPath).exists()) {
      return p.normalize(exactPath);
    }

    var fileName = '';
    if (normalizedRef.toUpperCase().startsWith('LFB:')) {
      fileName = normalizedRef.substring(4).trim();
    } else {
      fileName = p.basename(normalizedRef).trim();
    }

    if (fileName.isEmpty) return null;
    if (!fileName.toLowerCase().endsWith('.zip')) {
      fileName = '$fileName.zip';
    }

    final candidates = <String>{};
    final appDir = await getApplicationDocumentsDirectory();

    void addCandidateDir(String dirPath) {
      final clean = dirPath.trim();
      if (clean.isEmpty) return;
      candidates.add(p.join(clean, fileName));
      candidates.add(p.join(clean, 'ListenfyBackups', fileName));
    }

    addCandidateDir(appDir.path);
    addCandidateDir(p.join(appDir.path, 'ListenfyBackups'));

    final refDir = p.dirname(exactPath);
    if (refDir != '.' && refDir.trim().isNotEmpty && refDir != exactPath) {
      addCandidateDir(refDir);
    }

    if (Platform.isAndroid) {
      addCandidateDir('/storage/emulated/0');
      addCandidateDir('/storage/emulated/0/Download');
      addCandidateDir('/storage/emulated/0/Documents');
      addCandidateDir('/sdcard');
      addCandidateDir('/sdcard/Download');
      addCandidateDir('/sdcard/Documents');
    }

    for (final candidate in candidates) {
      try {
        if (await File(candidate).exists()) {
          return p.normalize(candidate);
        }
      } catch (_) {
        // Ignorar directorios sin permiso o rutas inválidas.
      }
    }

    final searchRoots = <String>{
      p.join(appDir.path, 'ListenfyBackups'),
      appDir.path,
      if (Platform.isAndroid) ...{
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/sdcard/Download',
        '/sdcard/Documents',
      },
    };

    for (final root in searchRoots) {
      final found = await _searchBackupZipInDir(root, fileName);
      if (found != null) return found;
    }

    return null;
  }

  String _normalizeBackupReference(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return '';

    final codeMatch = RegExp(
      r'(LFB:[^\s]+\.zip)',
      caseSensitive: false,
    ).firstMatch(raw.replaceAll('\n', ' '));
    if (codeMatch != null) {
      return codeMatch.group(1)!.trim();
    }

    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.endsWith('.zip') ||
          line.startsWith('/') ||
          line.startsWith('file://')) {
        return line;
      }
    }

    return raw;
  }

  Future<String?> _searchBackupZipInDir(
    String rootPath,
    String fileName,
  ) async {
    final root = Directory(rootPath);
    try {
      if (!await root.exists()) return null;
    } catch (_) {
      return null;
    }

    var seen = 0;

    Future<String?> walk(Directory dir, int depth) async {
      if (depth > 2) return null;

      Stream<FileSystemEntity> stream;
      try {
        stream = dir.list(followLinks: false);
      } catch (_) {
        return null;
      }

      await for (final entity in stream) {
        seen++;
        if (seen % 50 == 0) {
          await _yieldUi();
        }

        try {
          if (entity is File) {
            if (p.basename(entity.path).toLowerCase() ==
                fileName.toLowerCase()) {
              return p.normalize(entity.path);
            }
            continue;
          }

          if (entity is Directory) {
            final found = await walk(entity, depth + 1);
            if (found != null) return found;
          }
        } catch (_) {
          // Ignorar entradas inaccesibles.
        }
      }

      return null;
    }

    return walk(root, 0);
  }

  Future<Directory?> _resolveBackupDir() async {
    if (Platform.isAndroid) {
      final picked = await FilePicker.platform.getDirectoryPath();
      if (picked == null || picked.trim().isEmpty) {
        return null;
      }
      return Directory(p.join(picked, 'ListenfyBackups'));
    }

    final appDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDir.path, 'ListenfyBackups'));
  }

  String _backupFileName() {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'listenfy_backup_$stamp.zip';
  }

  String _relativeBackupPath(String appRoot, String absolutePath) {
    final normalized = p.normalize(absolutePath);
    if (p.isWithin(appRoot, normalized)) {
      return p.relative(normalized, from: appRoot);
    }
    final base = p.basename(normalized);
    final safe = '${normalized.hashCode}_$base';
    return p.join('external', safe);
  }
}
