import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

class BackupManifest {
  const BackupManifest({required this.version, required this.sections});

  final int version;
  final Map<String, String> sections;
}

class BackupService {
  static const manifestName = 'navi_backup.json';
  static const formatVersion = 1;

  static String fileName(DateTime at) {
    final y = at.year.toString().padLeft(4, '0');
    final m = at.month.toString().padLeft(2, '0');
    final d = at.day.toString().padLeft(2, '0');
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return 'navi-backup-$y$m$d-$hh$mm.zip';
  }

  static Future<Uint8List> buildZip(Map<String, String> sections) async {
    final archive = Archive();
    final manifest = <String, Object?>{
      'version': formatVersion,
      'app': 'NAVI',
      'exportedAt': DateTime.now().toIso8601String(),
      'sections': sections,
    };
    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    archive.addFile(
      ArchiveFile(manifestName, manifestBytes.length, manifestBytes),
    );

    try {
      final docs = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${docs.path}/media');
      if (await mediaDir.exists()) {
        await for (final entity in mediaDir.list(recursive: true)) {
          if (entity is! File) continue;
          final relative = entity.path.substring(docs.path.length + 1);
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(relative, bytes.length, bytes));
        }
      }
    } catch (_) {}

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  static BackupManifest readManifest(Uint8List zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final entry = archive.files.where((f) => f.name == manifestName).firstOrNull;
    if (entry == null) {
      throw const FormatException('not a NAVI backup');
    }
    final data =
        (jsonDecode(utf8.decode(entry.content as List<int>)) as Map)
            .cast<String, Object?>();
    final version = data['version'] as int? ?? 0;
    if (version > formatVersion) {
      throw const FormatException('backup came from a newer version of NAVI');
    }
    final raw = (data['sections'] as Map? ?? {}).cast<String, Object?>();
    return BackupManifest(
      version: version,
      sections: {
        for (final e in raw.entries)
          if (e.value is String) e.key: e.value as String,
      },
    );
  }

  static Future<int> restoreMedia(Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final docs = await getApplicationDocumentsDirectory();
    var written = 0;
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith('media/')) continue;
      if (file.name.contains('..')) continue;
      final target = File('${docs.path}/${file.name}');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(file.content as List<int>);
      written++;
    }
    return written;
  }
}
