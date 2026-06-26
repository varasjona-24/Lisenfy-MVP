import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../sources/ui/source_color_picker_field.dart';
import '../controller/edit_entity_controller.dart';
import '../../../app/ui/widgets/dialogs/image_search_dialog.dart';

class CreateEntityPage extends StatefulWidget {
  const CreateEntityPage({super.key});

  @override
  State<CreateEntityPage> createState() => _CreateEntityPageState();
}

class _CreateEntityPageState extends State<CreateEntityPage> {
  final EditEntityController _controller = Get.find<EditEntityController>();

  late final CreateEntityArgs _args;
  late final TextEditingController _nameCtrl;
  String? _localThumbPath;
  int? _colorValue;

  bool get _isTopic => _args.type == CreateEntityType.topic;
  bool get _isTopicPlaylist => _args.type == CreateEntityType.topicPlaylist;
  bool get _isCaptureTag => _args.type == CreateEntityType.captureTag;
  bool get _isCollection => _isTopic || _isTopicPlaylist;
  bool get _usesWideCover => _isCollection || _isCaptureTag;

  @override
  void initState() {
    super.initState();
    _args = Get.arguments as CreateEntityArgs;
    _nameCtrl = TextEditingController(text: _args.initialName ?? '');
    _colorValue = _args.initialColorValue;

    if (Get.isRegistered<NavigationController>()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<NavigationController>().setEditing(true);
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    if (Get.isRegistered<NavigationController>()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<NavigationController>().setEditing(false);
      });
    }
    super.dispose();
  }

  String _title() {
    if (_isCaptureTag) return tr('edit.create_tag');
    return _isCollection
        ? tr('edit.create_collection')
        : tr('edit.create_playlist');
  }

  Future<void> _pickLocalThumbnail() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    final file = (res != null && res.files.isNotEmpty) ? res.files.first : null;
    final path = file?.path;
    if (path == null || path.trim().isEmpty) return;

    final cropped = _usesWideCover
        ? await _controller.cropToVideoThumbnail(path)
        : await _controller.cropToSquare(path);
    if (cropped == null || cropped.trim().isEmpty) return;

    final persisted = await _controller.persistCroppedImage(
      id: _args.storageId,
      croppedPath: cropped,
    );
    if (!mounted || persisted == null || persisted.trim().isEmpty) return;

    setState(() {
      _localThumbPath = persisted;
    });
  }

  Future<void> _searchWebThumbnail() async {
    final rawQuery = _nameCtrl.text.trim();
    final query = rawQuery.isEmpty ? 'album cover' : rawQuery;

    final pickedUrl = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ImageSearchDialog(initialQuery: query),
    );

    final cleaned = (pickedUrl ?? '').trim();
    if (!mounted || cleaned.isEmpty) return;

    String? baseLocal;
    try {
      baseLocal = await _controller.cacheRemoteToLocal(
        id: '${_args.storageId}-raw',
        url: cleaned,
      );
    } catch (_) {
      baseLocal = null;
    }
    if (!mounted || baseLocal == null || baseLocal.trim().isEmpty) return;

    final cropped = _usesWideCover
        ? await _controller.cropToVideoThumbnail(baseLocal)
        : await _controller.cropToSquare(baseLocal);
    if (!mounted || cropped == null || cropped.trim().isEmpty) {
      await _controller.deleteFile(baseLocal);
      return;
    }

    final persisted = await _controller.persistCroppedImage(
      id: _args.storageId,
      croppedPath: cropped,
    );
    if (!mounted || persisted == null || persisted.trim().isEmpty) return;

    if (baseLocal != persisted) {
      await _controller.deleteFile(baseLocal);
    }

    setState(() {
      _localThumbPath = persisted;
    });
  }

  void _clearThumbnail() {
    setState(() {
      _localThumbPath = null;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Get.snackbar(
        _isCaptureTag
            ? tr('edit.entity_type.tag')
            : _isTopicPlaylist
            ? tr('edit.entity_type.collection')
            : tr('edit.entity_type.playlist'),
        tr('edit.validation.name_empty'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final ok = _isCaptureTag
        ? await _controller.createCaptureTag(
            name: name,
            colorValue: _colorValue,
          )
        : _isTopic
        ? await _controller.createTopic(
            themeId: _args.themeId!,
            name: name,
            localThumbPath: _localThumbPath,
            colorValue: _colorValue,
          )
        : _isTopicPlaylist
        ? await _controller.createTopicPlaylist(
            topicId: _args.topicId!,
            parentId: _args.parentId,
            depth: _args.depth ?? 1,
            name: name,
            localThumbPath: _localThumbPath,
            colorValue: _colorValue,
          )
        : await _controller.createPlaylist(
            name: name,
            localThumbPath: _localThumbPath,
          );

    if (!ok && mounted) {
      Get.snackbar(
        _isCaptureTag ? 'Etiquetas' : 'Collections',
        tr('edit.limit_reached'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (mounted) Get.back(result: true);
  }

  Widget _buildThumbnail(BuildContext context) {
    final theme = Theme.of(context);
    final local = _localThumbPath?.trim();
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return Image.file(
        File(local),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackThumb(theme),
      );
    }
    return _fallbackThumb(theme);
  }

  Widget _fallbackThumb(ThemeData theme) {
    return Center(
      child: Icon(
        _isCaptureTag ? Icons.folder_rounded : Icons.queue_music_rounded,
        size: 44,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_title()),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Crear'),
          ),
        ),
      ),
      body: AppGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: _usesWideCover ? 126 : 88,
                        height: _usesWideCover ? 71 : 88,
                        child: _buildThumbnail(context),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _nameCtrl.text.isEmpty
                            ? (_isCaptureTag
                                  ? tr('edit.create_tag')
                                  : _isCollection
                                  ? tr('edit.create_collection')
                                  : tr('edit.create_playlist'))
                            : _nameCtrl.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Informacion basica',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(
                      _isCaptureTag
                          ? Icons.folder_rounded
                          : Icons.queue_music_rounded,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isCaptureTag
                  ? 'Color de etiqueta'
                  : _isCollection
                  ? tr('edit.collection_cover_color')
                  : 'Portada',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!_isCaptureTag) ...[
                      _CoverActionTile(
                        icon: Icons.photo_library_rounded,
                        title: 'Elegir imagen',
                        subtitle: 'Usar una portada guardada en el dispositivo',
                        onTap: _pickLocalThumbnail,
                      ),
                      const SizedBox(height: 8),
                      _CoverActionTile(
                        icon: Icons.public_rounded,
                        title: 'Buscar en web',
                        subtitle: 'Encontrar y recortar una portada online',
                        onTap: _searchWebThumbnail,
                      ),
                      if ((_localThumbPath ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _CoverActionTile(
                          icon: Icons.hide_image_rounded,
                          title: 'Quitar portada',
                          subtitle: 'Volver al icono predeterminado',
                          onTap: _clearThumbnail,
                          destructive: true,
                        ),
                      ],
                    ],
                    if (_isCollection || _isCaptureTag) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Color',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SourceColorPickerField(
                        color: _colorValue != null
                            ? Color(_colorValue!)
                            : theme.colorScheme.primary,
                        showLabel: !_isCaptureTag,
                        onChanged: (c) => setState(() {
                          _colorValue = c.toARGB32();
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverActionTile extends StatelessWidget {
  const _CoverActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = destructive ? scheme.error : scheme.primary;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.52),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: tint, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: destructive ? scheme.error : scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
