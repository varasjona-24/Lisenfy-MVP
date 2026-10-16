class ArtistCredits {
  const ArtistCredits({
    required this.rawArtist,
    required this.primaryArtist,
    required this.collaborators,
    this.artistKeys,
  });

  final String rawArtist;
  final String primaryArtist;
  final List<String> collaborators;
  final List<String>? artistKeys;

  bool get hasCollaborators => collaborators.isNotEmpty;

  List<String> get allArtists {
    if (artistKeys != null) {
      return [
        primaryArtist,
        ...collaborators,
      ].where((name) => name.isNotEmpty).toList();
    }
    final ordered = <String>[];
    final seen = <String>{};

    for (final name in [primaryArtist, ...collaborators]) {
      final cleaned = ArtistCreditParser.cleanName(name);
      final key = ArtistCreditParser.normalizeKey(cleaned);
      if (cleaned.isEmpty || seen.contains(key)) continue;
      ordered.add(cleaned);
      seen.add(key);
    }

    return ordered;
  }

  bool containsArtistKey(String artistKey) {
    final key = ArtistCreditParser.normalizeKey(artistKey);
    if (key.isEmpty) return false;
    if (artistKeys != null && artistKeys!.contains(key)) return true;
    return allArtists.any(
      (name) => ArtistCreditParser.normalizeKey(name) == key,
    );
  }

  bool isPrimaryArtistKey(String artistKey) {
    final key = ArtistCreditParser.normalizeKey(artistKey);
    if (key.isEmpty) return false;
    if (artistKeys != null &&
        artistKeys!.isNotEmpty &&
        artistKeys!.first == key) {
      return true;
    }
    return ArtistCreditParser.normalizeKey(primaryArtist) == key;
  }

  bool isCollaborationForArtistKey(String artistKey) {
    return containsArtistKey(artistKey) && !isPrimaryArtistKey(artistKey);
  }
}

class ArtistCreditParser {
  static final RegExp _artistMarkerPattern = RegExp(
    r'\b(feat\.?|ft\.?|featuring|with)\b',
    caseSensitive: false,
  );
  static final RegExp _titleHintPattern = RegExp(
    r'\b(feat\.?|ft\.?|featuring)\b',
    caseSensitive: false,
  );
  static final RegExp _collaboratorSeparatorPattern = RegExp(
    r'\s*,\s*|\s*&\s*|\s+[xX]\s+',
  );
  static final RegExp _edgeJunkPattern = RegExp(
    r'^[\s\-:;,.()[\]{}]+|[\s\-:;,.()[\]{}]+$',
  );
  static final RegExp _multiSpacePattern = RegExp(r'\s+');

  static ArtistCredits parse(String rawArtist) {
    final raw = rawArtist.trim();
    if (raw.isEmpty) {
      return const ArtistCredits(
        rawArtist: '',
        primaryArtist: '',
        collaborators: <String>[],
      );
    }

    final match = _artistMarkerPattern.firstMatch(raw);
    if (match == null) {
      return ArtistCredits(
        rawArtist: raw,
        primaryArtist: cleanName(raw),
        collaborators: const <String>[],
      );
    }

    final primary = cleanName(raw.substring(0, match.start));
    final rawCollaborators = raw.substring(match.end).trim();
    final normalizedCollaborators = rawCollaborators.replaceAll(
      _artistMarkerPattern,
      ',',
    );

    final collaborators = _dedupe(
      normalizedCollaborators
          .split(_collaboratorSeparatorPattern)
          .map(cleanName)
          .where((name) => name.isNotEmpty),
    );

    return ArtistCredits(
      rawArtist: raw,
      primaryArtist: primary,
      collaborators: collaborators,
    );
  }

  static bool titleSuggestsCollaboration(String title) {
    return _titleHintPattern.hasMatch(title.trim());
  }

  static bool artistFieldHasCollaborators(String rawArtist) {
    return parse(rawArtist).hasCollaborators;
  }

  static String replaceArtistName(
    String rawArtistField, {
    required String artistKey,
    required String newName,
  }) {
    final normalizedTarget = normalizeKey(artistKey);
    final cleanedNewName = cleanName(newName);
    if (normalizedTarget.isEmpty || cleanedNewName.isEmpty) {
      return rawArtistField.trim();
    }

    final raw = rawArtistField.trim();
    if (raw.isEmpty) return cleanedNewName;

    final parsed = parse(raw);
    if (!parsed.hasCollaborators) {
      final current = cleanName(parsed.primaryArtist);
      if (normalizeKey(current) == normalizedTarget) {
        return cleanedNewName;
      }
      return raw;
    }

    final updatedPrimary =
        normalizeKey(parsed.primaryArtist) == normalizedTarget
        ? cleanedNewName
        : cleanName(parsed.primaryArtist);

    final updatedCollaborators = _dedupe(
      parsed.collaborators.map(
        (name) =>
            normalizeKey(name) == normalizedTarget ? cleanedNewName : name,
      ),
    );

    final marker = _resolveMarker(raw);
    final primary = updatedPrimary.isEmpty ? cleanedNewName : updatedPrimary;
    if (updatedCollaborators.isEmpty) return primary;

    return '$primary $marker ${_joinCollaborators(updatedCollaborators)}';
  }

  static String normalizeKey(String raw) {
    final cleaned = cleanName(raw).toLowerCase();
    return cleaned.isEmpty ? 'unknown' : cleaned;
  }

  static String cleanName(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';

    while (_edgeJunkPattern.hasMatch(value)) {
      final next = value.replaceAll(_edgeJunkPattern, '').trim();
      if (next == value) break;
      value = next;
    }

    value = value.replaceAll(_multiSpacePattern, ' ').trim();
    return value;
  }

  static String _resolveMarker(String rawArtistField) {
    final match = _artistMarkerPattern.firstMatch(rawArtistField);
    final rawMarker = match?.group(0)?.trim().toLowerCase() ?? 'feat.';
    return rawMarker.isEmpty ? 'feat.' : rawMarker;
  }

  static List<String> _dedupe(Iterable<String> names) {
    final seen = <String>{};
    final result = <String>[];

    for (final raw in names) {
      final cleaned = cleanName(raw);
      final key = normalizeKey(cleaned);
      if (cleaned.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(cleaned);
    }

    return result;
  }

  static String _joinCollaborators(List<String> collaborators) {
    if (collaborators.isEmpty) return '';
    if (collaborators.length == 1) return collaborators.first;
    if (collaborators.length == 2) {
      return '${collaborators.first} & ${collaborators.last}';
    }
    return '${collaborators.sublist(0, collaborators.length - 1).join(', ')} & ${collaborators.last}';
  }
}
