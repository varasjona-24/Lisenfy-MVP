import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/capture_item.dart';

class CapturePreviewPage extends StatelessWidget {
  const CapturePreviewPage({
    super.key,
    required this.capture,
    required this.onRename,
    required this.onDelete,
  });

  final CaptureItem capture;
  final Future<void> Function() onRename;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          capture.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => onRename(),
            icon: const Icon(Icons.drive_file_rename_outline_rounded),
            tooltip: 'Renombrar',
          ),
          IconButton(
            onPressed: () => onDelete(),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Eliminar',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: .8,
          maxScale: 4,
          child: Image.file(File(capture.path), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
