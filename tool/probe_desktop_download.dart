import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:listenfy/app/data/downloads/desktop_download_engine.dart';

/// Explicit development probe; never writes to the user's library.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Uso: dart run tool/probe_desktop_download.dart URL');
    exitCode = 64;
    return;
  }
  final dir = await Directory.systemTemp.createTemp('listenfy-probe-');
  try {
    final engine = await DesktopDownloadEngine.discover();
    final info = await engine.resolve(arguments.single);
    stdout.writeln('Metadatos: ${info['title']}');
    final path = p.join(dir.path, 'probe.mp3');
    await engine.download(
      arguments.single,
      path,
      kind: 'audio',
      format: 'mp3',
      quality: 'low',
    );
    stdout.writeln(
      'Descarga local completada: ${await File(path).length()} bytes.',
    );
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    await dir.delete(recursive: true);
  }
}
