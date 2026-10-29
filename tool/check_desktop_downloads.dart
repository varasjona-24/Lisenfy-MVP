import 'dart:io';
import 'package:listenfy/app/data/downloads/desktop_download_engine.dart';

Future<void> main() async {
  try {
    final engine = await DesktopDownloadEngine.discover();
    for (final tool in [
      (engine.ytDlp, '--version'),
      (engine.ffmpeg, '-version'),
      (engine.runtime, '--version'),
    ]) {
      final output = await DesktopDownloadEngine.runCommand(tool.$1, [
        tool.$2,
      ], null);
      stdout.writeln('${tool.$1}: ${output.split('\n').first}');
    }
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
