import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Sizes the preview from the original pixels, including portrait screenshots.
class CaptureImagePreview extends StatefulWidget {
  const CaptureImagePreview({
    super.key,
    required this.path,
    this.maxHeight = 420,
  });
  final String path;
  final double maxHeight;
  @override
  State<CaptureImagePreview> createState() => _CaptureImagePreviewState();
}

class _CaptureImagePreviewState extends State<CaptureImagePreview> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double _ratio = 1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(CaptureImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _ratio = 1;
      _resolve();
    }
  }

  void _resolve() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = FileImage(
      File(widget.path),
    ).resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener((info, _) {
      final ratio = info.image.width / info.image.height;
      info.dispose();
      if (mounted && ratio != _ratio) setState(() => _ratio = ratio);
    }, onError: (Object _, StackTrace? _) {});
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = math.min(widget.maxHeight, constraints.maxHeight);
      final width = math.min(constraints.maxWidth, height * _ratio);
      return Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: _ratio,
            child: Image.file(
              File(widget.path),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      );
    },
  );
}
