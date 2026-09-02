import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:navi/services/backup_service.dart';

void main() {
  group('BackupService', () {
    test('file name is sortable and zip-suffixed', () {
      final name = BackupService.fileName(DateTime(2026, 3, 7, 9, 5));
      expect(name, 'navi-backup-20260307-0905.zip');
    });

    test('sections survive a zip round trip', () async {
      final sections = {
        'habits': jsonEncode({
          'habits': [
            {'id': 1, 'name': 'Read'},
          ],
        }),
        'journal': jsonEncode({'entries': []}),
      };
      final bytes = await BackupService.buildZip(sections);
      final manifest = BackupService.readManifest(bytes);
      expect(manifest.version, BackupService.formatVersion);
      expect(manifest.sections['habits'], sections['habits']);
      expect(manifest.sections['journal'], sections['journal']);
    });

    test('a zip without a manifest is rejected', () async {
      final bytes = await BackupService.buildZip({'habits': '{}'});
      final corrupted = bytes.sublist(0, bytes.length ~/ 2);
      expect(() => BackupService.readManifest(corrupted), throwsA(anything));
    });
  });
}
