import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DesktopImageCropperDialog extends StatefulWidget {
  const DesktopImageCropperDialog({
    super.key,
    required this.sourcePath,
    required this.ratioX,
    required this.ratioY,
    this.title = 'Recortar imagen',
  });

  final String sourcePath;
  final double ratioX;
  final double ratioY;
  final String title;

  @override
  State<DesktopImageCropperDialog> createState() =>
      _DesktopImageCropperDialogState();
}

class _DesktopImageCropperDialogState extends State<DesktopImageCropperDialog> {
  ui.Image? _image;
  Object? _error;
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Size _lastCropSize = Size.zero;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.sourcePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _image = frame.image;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  double get _ratio => widget.ratioX / widget.ratioY;

  Size _cropSizeFor(BoxConstraints constraints) {
    final maxWidth = math.min(constraints.maxWidth, 720.0);
    final maxHeight = math.min(constraints.maxHeight, 470.0);
    var width = maxWidth;
    var height = width / _ratio;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * _ratio;
    }
    return Size(width, height);
  }

  void _clampOffset(Size cropSize) {
    final image = _image;
    if (image == null || cropSize.isEmpty) return;

    final baseScale = math.max(
      cropSize.width / image.width,
      cropSize.height / image.height,
    );
    final drawWidth = image.width * baseScale * _scale;
    final drawHeight = image.height * baseScale * _scale;
    final maxDx = math.max(0.0, (drawWidth - cropSize.width) / 2);
    final maxDy = math.max(0.0, (drawHeight - cropSize.height) / 2);
    _offset = Offset(
      _offset.dx.clamp(-maxDx, maxDx),
      _offset.dy.clamp(-maxDy, maxDy),
    );
  }

  Future<void> _save(Size cropSize) async {
    final image = _image;
    if (image == null || cropSize.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      _clampOffset(cropSize);
      final wide = widget.ratioX >= widget.ratioY;
      final outputWidth = wide ? 1280 : (1280 * _ratio).round();
      final outputHeight = wide ? (1280 / _ratio).round() : 1280;
      final outputScale = outputWidth / cropSize.width;

      final baseScale = math.max(
        cropSize.width / image.width,
        cropSize.height / image.height,
      );
      final drawWidth = image.width * baseScale * _scale;
      final drawHeight = image.height * baseScale * _scale;
      final left = cropSize.width / 2 + _offset.dx - drawWidth / 2;
      final top = cropSize.height / 2 + _offset.dy - drawHeight / 2;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(
          left * outputScale,
          top * outputScale,
          drawWidth * outputScale,
          drawHeight * outputScale,
        ),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final cropped = await picture.toImage(outputWidth, outputHeight);
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File(
        p.join(
          tempDir.path,
          'listenfy-crop-${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (mounted) Navigator.of(context).pop(file.path);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = _image;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    widget.title == 'Recortar imagen'
                        ? tr('edit.crop_image')
                        : widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: tr('common.close'),
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop<String>(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (_error != null) {
                      return Center(child: Text(tr('edit.image_load_error')));
                    }
                    if (image == null) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final cropSize = _cropSizeFor(constraints);
                    _lastCropSize = cropSize;
                    _clampOffset(cropSize);

                    return Center(
                      child: GestureDetector(
                        onScaleStart: (_) {
                          _startScale = _scale;
                          _startOffset = _offset;
                        },
                        onScaleUpdate: (details) {
                          setState(() {
                            _scale = (_startScale * details.scale).clamp(
                              1.0,
                              5.0,
                            );
                            _offset = _startOffset + details.focalPointDelta;
                            _clampOffset(cropSize);
                          });
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox.fromSize(
                            size: cropSize,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Colors.black,
                              ),
                              child: CustomPaint(
                                painter: _CropPreviewPainter(
                                  image: image,
                                  scale: _scale,
                                  offset: _offset,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: tr('edit.zoom_out'),
                    onPressed: _saving
                        ? null
                        : () {
                            setState(() {
                              _scale = math.max(1, _scale - 0.1);
                              _clampOffset(_lastCropSize);
                            });
                          },
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Expanded(
                    child: Slider(
                      value: _scale,
                      min: 1,
                      max: 5,
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() {
                                _scale = value;
                                _clampOffset(_lastCropSize);
                              });
                            },
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: tr('edit.zoom_in'),
                    onPressed: _saving
                        ? null
                        : () {
                            setState(() {
                              _scale = math.min(5, _scale + 0.1);
                              _clampOffset(_lastCropSize);
                            });
                          },
                    icon: const Icon(Icons.add_rounded),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop<String>(),
                    child: Text(tr('common.cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _save(_lastCropSize),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(tr('common.save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropPreviewPainter extends CustomPainter {
  const _CropPreviewPainter({
    required this.image,
    required this.scale,
    required this.offset,
  });

  final ui.Image image;
  final double scale;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final baseScale = math.max(
      size.width / image.width,
      size.height / image.height,
    );
    final drawWidth = image.width * baseScale * scale;
    final drawHeight = image.height * baseScale * scale;
    final left = size.width / 2 + offset.dx - drawWidth / 2;
    final top = size.height / 2 + offset.dy - drawHeight / 2;

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(left, top, drawWidth, drawHeight),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPreviewPainter oldDelegate) {
    return image != oldDelegate.image ||
        scale != oldDelegate.scale ||
        offset != oldDelegate.offset;
  }
}
