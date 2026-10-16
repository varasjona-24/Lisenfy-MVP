/// Library phase occupies 40–70% of the restore. Unknown streaming totals
/// have no numeric percentage; never estimate them with repeating blocks.
double? libraryRestoreProgress({required int completed, required int? total}) {
  if (total == null) return null;
  if (total <= 0) return 0.7;
  return 0.4 + 0.3 * (completed / total).clamp(0.0, 1.0);
}
