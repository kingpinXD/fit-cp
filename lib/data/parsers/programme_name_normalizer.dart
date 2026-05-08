/// Normalizes a filename into a clean programme name.
///
/// Steps mirror the Kotlin `ProgrammeNameNormalizer`:
/// strip extension, underscores → spaces, lowercase, drop noise words,
/// collapse spaces, trim, spaces → underscores, collapse underscores,
/// fall back to parent folder if result is too short.
class ProgrammeNameNormalizer {
  static const _noiseWords = {'the', 'edited', 'spreadsheet', 'sheet', 'program'};

  static String normalize(String filename, {String parentFolder = ''}) {
    var name = _stripExtension(filename);
    name = name.replaceAll('_', ' ');
    name = name.toLowerCase();
    name = _removeNoiseWords(name);
    name = name.replaceAll(' - ', ' ');
    name = name.replaceAll(RegExp(r' {2,}'), ' ');
    name = _trimSpacesAndHyphens(name);
    name = name.replaceAll(' ', '_');
    name = name.replaceAll(RegExp(r'_{2,}'), '_');

    if (name.length <= 4 && parentFolder.isNotEmpty) {
      final prefix = _cleanFolder(parentFolder);
      name = name.isEmpty ? prefix : '${prefix}_$name';
    }

    return name;
  }

  static String _stripExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot > 0 ? filename.substring(0, dot) : filename;
  }

  static String _removeNoiseWords(String text) {
    var result = text;
    for (final word in _noiseWords) {
      result = result.replaceAll(
        RegExp('(?<=^|[\\s-])$word(?=\$|[\\s-])', caseSensitive: false),
        '',
      );
    }
    result = result.replaceAll(RegExp(r'-+$'), '');
    result = result.replaceAll(RegExp(r'^-+'), '');
    return result;
  }

  static String _trimSpacesAndHyphens(String text) {
    var start = 0;
    var end = text.length;
    while (start < end && (text[start] == ' ' || text[start] == '-')) {
      start++;
    }
    while (end > start && (text[end - 1] == ' ' || text[end - 1] == '-')) {
      end--;
    }
    return text.substring(start, end);
  }

  /// Same cleanup as [normalize] without the short-name fallback.
  static String _cleanFolder(String folder) {
    var name = folder.replaceAll('_', ' ');
    name = name.toLowerCase();
    name = _removeNoiseWords(name);
    name = name.replaceAll(' - ', ' ');
    name = name.replaceAll(RegExp(r' {2,}'), ' ');
    name = _trimSpacesAndHyphens(name);
    name = name.replaceAll(' ', '_');
    name = name.replaceAll(RegExp(r'_{2,}'), '_');
    return name;
  }
}
