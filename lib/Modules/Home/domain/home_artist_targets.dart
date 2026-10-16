import '../../../app/utils/artist_credit_parser.dart';
import 'home_layout_models.dart';

/// Legacy name shortcuts may resolve only when unambiguous. Stable IDs win.
Set<String> resolveHomeArtistTargets(
  String targets,
  List<HomeArtistChoice> choices,
) {
  final resolved = <String>{};
  for (final raw in targets.split('|')) {
    final target = ArtistCreditParser.normalizeKey(raw);
    final exact = choices
        .where((choice) => choice.key == raw.trim() || choice.key == target)
        .toList();
    if (exact.isNotEmpty) {
      resolved.addAll(exact.map((choice) => choice.key));
      continue;
    }
    final named = choices
        .where(
          (choice) => ArtistCreditParser.normalizeKey(choice.name) == target,
        )
        .toList();
    if (named.length == 1) resolved.add(named.single.key);
  }
  return resolved;
}

String removeHomeArtistTargets(
  String targets,
  Iterable<String> removedIds,
  List<HomeArtistChoice> choices,
) {
  final removed = removedIds.toSet();
  return targets
      .split('|')
      .where(
        (raw) => !resolveHomeArtistTargets(raw, choices).any(removed.contains),
      )
      .join('|');
}
