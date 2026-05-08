import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/models/import_result.dart';
import '../../data/parsers/programme_name_normalizer.dart';
import 'programme_notifier.dart';

class ImportSelection {
  const ImportSelection({
    required this.bytes,
    required this.programmeName,
    required this.isJson,
  });

  final Uint8List bytes;
  final String programmeName;
  final bool isJson;
}

Future<ImportSelection?> pickProgrammeFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.any,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final f = result.files.first;
  final filename = f.name;
  final parentFolder = _parentFolder(f.path);
  final programmeName =
      ProgrammeNameNormalizer.normalize(filename, parentFolder: parentFolder);
  final isJson = filename.toLowerCase().endsWith('.json') ||
      filename.toLowerCase().contains('json');

  Uint8List? bytes = f.bytes;
  if (bytes == null && f.path != null) {
    bytes = await File(f.path!).readAsBytes();
  }
  if (bytes == null) return null;

  return ImportSelection(
    bytes: bytes,
    programmeName: programmeName,
    isJson: isJson,
  );
}

String _parentFolder(String? path) {
  if (path == null) return '';
  final segments =
      path.split(Platform.pathSeparator).where((s) => s.isNotEmpty).toList();
  if (segments.length < 2) return '';
  return segments[segments.length - 2];
}

Future<ImportResult?> applyImport(
  ProgrammeNotifier notifier,
  ImportSelection sel,
) async {
  if (sel.isJson) {
    final json = String.fromCharCodes(sel.bytes);
    return notifier.importProgramme(json, sel.programmeName);
  }
  return notifier.importProgrammeFromXlsx(sel.bytes, sel.programmeName);
}

void showImportSnack(BuildContext context, ImportResult result, String name) {
  final msg = result == ImportResult.switched
      ? 'Switched to $name'
      : 'Imported $name';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
