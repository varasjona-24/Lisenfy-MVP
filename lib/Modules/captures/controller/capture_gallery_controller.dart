import 'package:get/get.dart';

import '../data/capture_gallery_store.dart';
import '../domain/capture_gallery_models.dart';
import '../services/capture_cover_service.dart';
import '../services/capture_share_service.dart';
import 'capture_gallery_logic.dart';

class CaptureGalleryController extends GetxController {
  CaptureGalleryController({
    CaptureGalleryStore? galleryStore,
    CaptureShareService? shareService,
    CaptureCoverService? coverService,
    CaptureGalleryLogic? logic,
  }) : _galleryStore = galleryStore ?? Get.find<CaptureGalleryStore>(),
       _shareService = shareService ?? Get.find<CaptureShareService>(),
       _coverService = coverService ?? Get.find<CaptureCoverService>(),
       _logic = logic ?? const CaptureGalleryLogic();

  final CaptureGalleryStore _galleryStore;
  final CaptureShareService _shareService;
  final CaptureCoverService _coverService;
  final CaptureGalleryLogic _logic;

  final isLoading = true.obs;
  final captures = <CaptureItem>[].obs;
  final tagColors = <String, int>{}.obs;
  final tagCollections = <String, CaptureTagCollection>{}.obs;
  final selectedPaths = <String>{}.obs;
  final query = ''.obs;
  final sort = CaptureSort.date.obs;
  final ascending = false.obs;

  static const maxShareSelection = 20;
  static const defaultTagColor = 0xFF7C8BA1;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  int get selectedCount => selectedPaths.length;
  bool get hasSelection => selectedPaths.isNotEmpty;

  List<CaptureItem> get visibleCaptures => _logic.filterAndSort(
    captures: captures,
    query: query.value,
    sort: sort.value,
    ascending: ascending.value,
  );

  String directionLabel(CaptureSort option) => _logic.directionLabel(
    option: option,
    current: sort.value,
    ascending: ascending.value,
  );

  Future<void> reload() async {
    isLoading.value = true;
    try {
      captures.assignAll(await _galleryStore.listCaptures());
      tagColors.assignAll(_galleryStore.tagColors());
      tagCollections.assignAll(
        _galleryStore.tagCollections(fallbackColor: defaultTagColor),
      );
      selectedPaths.removeWhere((path) {
        return !captures.any((capture) => capture.path == path);
      });
      selectedPaths.refresh();
    } finally {
      isLoading.value = false;
    }
  }

  void setQuery(String value) {
    query.value = value.trim().toLowerCase();
  }

  void pickSort(CaptureSort nextSort) {
    if (sort.value == nextSort) {
      ascending.toggle();
      return;
    }
    sort.value = nextSort;
    ascending.value = false;
  }

  bool toggleSelection(CaptureItem capture) {
    if (selectedPaths.contains(capture.path)) {
      selectedPaths.remove(capture.path);
      selectedPaths.refresh();
      return true;
    }
    if (selectedPaths.length >= maxShareSelection) return false;
    selectedPaths.add(capture.path);
    selectedPaths.refresh();
    return true;
  }

  void clearSelection() {
    selectedPaths.clear();
    selectedPaths.refresh();
  }

  Future<void> renameCapture(CaptureItem capture, String name) async {
    final next = name.trim();
    if (next.isEmpty) return;
    await _galleryStore.renameCapture(capture.path, next);
    await reload();
  }

  Future<void> deleteCapture(CaptureItem capture) async {
    await _galleryStore.deleteCapture(capture.path);
    selectedPaths.remove(capture.path);
    selectedPaths.refresh();
    await reload();
  }

  Future<void> setTags(CaptureItem capture, Iterable<String> tags) async {
    await _galleryStore.setTags(capture.path, tags);
    await reload();
  }

  Future<void> setTagColor(String tag, int colorValue) async {
    await _galleryStore.setTagColor(tag, colorValue);
    await reload();
  }

  Future<void> setTagCollection({
    required String tag,
    String? name,
    int? colorValue,
    String? thumbnailPath,
  }) async {
    await _galleryStore.setTagCollection(
      tag,
      name: name,
      colorValue: colorValue,
      thumbnailPath: thumbnailPath,
    );
    await reload();
  }

  Future<void> renameTag(String oldTag, String nextName) async {
    await _galleryStore.renameTag(oldTag, nextName);
    await reload();
  }

  int colorForTag(String tag) {
    final key = tag.trim().toLowerCase();
    return tagCollections[key]?.colorValue ?? tagColors[key] ?? defaultTagColor;
  }

  List<CaptureTagFolder> get tagFolders {
    final grouped = <String, List<CaptureItem>>{};
    final labels = <String, String>{};
    for (final capture in captures) {
      for (final tag in capture.tags) {
        final key = tag.trim().toLowerCase();
        if (key.isEmpty) continue;
        labels.putIfAbsent(key, () => tag.trim());
        grouped.putIfAbsent(key, () => <CaptureItem>[]).add(capture);
      }
    }
    final folders = grouped.entries.map((entry) {
      final collection = tagCollections[entry.key];
      return CaptureTagFolder(
        key: entry.key,
        tag: collection?.name ?? labels[entry.key] ?? entry.key,
        colorValue:
            collection?.colorValue ?? tagColors[entry.key] ?? defaultTagColor,
        thumbnailPath: collection?.thumbnailPath,
        captures: List<CaptureItem>.unmodifiable(entry.value),
      );
    }).toList();
    folders.sort((a, b) => a.tag.toLowerCase().compareTo(b.tag.toLowerCase()));
    return List<CaptureTagFolder>.unmodifiable(folders);
  }

  Future<void> shareCaptures(Iterable<CaptureItem> selected) async {
    await _shareService.shareExternal(selected);
  }

  Future<void> shareSelected() async {
    final selected = captures.where((capture) {
      return selectedPaths.contains(capture.path);
    });
    await shareCaptures(selected);
  }

  Future<List<CaptureCoverTarget>> loadCoverTargets() {
    return _coverService.loadTargets();
  }

  Future<void> applyCover({
    required CaptureItem capture,
    required CaptureCoverTarget target,
  }) async {
    await _coverService.applyCover(path: capture.path, target: target);
  }
}
