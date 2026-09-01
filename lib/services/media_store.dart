import 'dart:io';

import 'package:path_provider/path_provider.dart';

class MediaStore {
  static Directory? _docs;

  static Future<Directory> _documents() async =>
      _docs ??= await getApplicationDocumentsDirectory();

  /// Copies [sourcePath] into app storage. [onProgress] reports bytes copied
  /// out of the total; without it the copy runs in one shot.
  static Future<String> importFile(
    String sourcePath, {
    String? ext,
    void Function(int done, int total)? onProgress,
  }) async {
    final docs = await _documents();
    final now = DateTime.now();
    // media is bucketed by month so old files are easy to find and prune
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final dir = Directory('${docs.path}/media/$month');
    await dir.create(recursive: true);
    final extension = ext ?? sourcePath.split('.').last;
    final name = '${now.millisecondsSinceEpoch}.$extension';
    final destination = '${dir.path}/$name';
    final source = File(sourcePath);

    if (onProgress == null) {
      await source.copy(destination);
    } else {
      final total = await source.length();
      var done = 0;
      final sink = File(destination).openWrite();
      try {
        // addStream keeps the read back-pressured, so big videos don't buffer
        await sink.addStream(
          source.openRead().map((chunk) {
            done += chunk.length;
            onProgress(done, total);
            return chunk;
          }),
        );
        await sink.flush();
      } finally {
        await sink.close();
      }
      onProgress(total, total);
    }
    return 'media/$month/$name';
  }

  static Future<String> newRecordingPath(String ext) async {
    final docs = await _documents();
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final dir = Directory('${docs.path}/media/$month');
    await dir.create(recursive: true);
    return '${dir.path}/${now.millisecondsSinceEpoch}.$ext';
  }

  static Future<String> toRelative(String absolutePath) async {
    final docs = await _documents();
    if (absolutePath.startsWith('${docs.path}/')) {
      return absolutePath.substring(docs.path.length + 1);
    }
    return absolutePath;
  }

  static Future<String> absolutePath(String relativePath) async {
    if (relativePath.startsWith('/')) return relativePath;
    final docs = await _documents();
    return '${docs.path}/$relativePath';
  }

  static Future<File?> fileFor(String? relativePath) async {
    if (relativePath == null) return null;
    final file = File(await absolutePath(relativePath));
    return await file.exists() ? file : null;
  }

  static Future<void> delete(String? relativePath) async {
    if (relativePath == null) return;
    try {
      final file = File(await absolutePath(relativePath));
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
