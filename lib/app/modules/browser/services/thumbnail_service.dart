import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  ThumbnailService({int targetSide = 400, int batchSize = 20})
    : _targetSide = targetSide,
      _batchSize = batchSize;

  final int _targetSide;
  final int _batchSize;

  String? _cacheRootPath;
  int _jobId = 0;

  final Map<String, String> _resolvedThumbnailBySourcePath = <String, String>{};

  void clearResolvedCache() {
    _resolvedThumbnailBySourcePath.clear();
  }

  String? getResolvedThumbnailPath(String sourcePath) {
    return _resolvedThumbnailBySourcePath[sourcePath];
  }

  String? resolveThumbnailPathSync(String sourcePath, double size) {
    return _resolvedThumbnailBySourcePath[sourcePath];
  }

  Future<void> preGenerateForFolder(
    String folderPath,
    List<String> imagePaths, {
    void Function()? onProgress,
  }) async {
    if (imagePaths.isEmpty) return;

    final currentJobId = ++_jobId;

    final cacheRoot = await _ensureCacheRootPath();
    final cacheDir = p.join(cacheRoot, 'thumb_$_targetSide');
    Directory(cacheDir).createSync(recursive: true);

    for (var i = 0; i < imagePaths.length; i += _batchSize) {
      if (currentJobId != _jobId) return;

      final end = (i + _batchSize) > imagePaths.length
          ? imagePaths.length
          : (i + _batchSize);
      final chunk = imagePaths.sublist(i, end);

      final resolved = await Isolate.run(
        () => _generateAndResolveForSourcesSync(chunk, cacheDir, _targetSide),
      );
      _resolvedThumbnailBySourcePath.addAll(resolved);

      onProgress?.call();
    }
  }

  Future<String> _ensureCacheRootPath() async {
    final cached = _cacheRootPath;
    if (cached != null) return cached;

    final dir = await getApplicationSupportDirectory();
    final root = p.join(dir.path, 'organimage_cache');
    Directory(root).createSync(recursive: true);
    _cacheRootPath = root;
    return root;
  }
}

Map<String, String> _generateAndResolveForSourcesSync(
  List<String> sources,
  String cacheDir,
  int targetSide,
) {
  final resolved = <String, String>{};

  for (final src in sources) {
    try {
      final ext = p.extension(src).toLowerCase();
      if (ext == '.svg') continue;

      final srcFile = File(src);
      if (!srcFile.existsSync()) continue;

      final fingerprint = _contentFingerprintSync(srcFile);
      final dstPng = p.join(cacheDir, '${fingerprint}_$targetSide.png');
      final dstJpg = p.join(cacheDir, '${fingerprint}_$targetSide.jpg');

      if (File(dstPng).existsSync()) {
        resolved[src] = dstPng;
        continue;
      }
      if (File(dstJpg).existsSync()) {
        resolved[src] = dstJpg;
        continue;
      }

      final bytes = srcFile.readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) continue;

      final square = img.copyResizeCropSquare(decoded, size: targetSide);

      final bool hasAlpha = square.numChannels == 4;
      final String dst = hasAlpha ? dstPng : dstJpg;
      resolved[src] = dst;

      final List<int> encoded = hasAlpha
          ? img.encodePng(square, level: 6)
          : img.encodeJpg(square, quality: 85);

      final dstFile = File(dst);
      dstFile.parent.createSync(recursive: true);

      final tmpPath = '$dst.tmp';
      final tmpFile = File(tmpPath);
      tmpFile.writeAsBytesSync(encoded, flush: true);
      tmpFile.renameSync(dst);
    } catch (_) {
      // ignore
    }
  }

  return resolved;
}

String _contentFingerprintSync(File file) {
  final stat = file.statSync();
  final size = stat.size;

  const sampleSize = 64 * 1024;
  final raf = file.openSync(mode: FileMode.read);
  try {
    final headLen = size < sampleSize ? size : sampleSize;
    raf.setPositionSync(0);
    final head = raf.readSync(headLen);

    List<int> tail = const <int>[];
    if (size > sampleSize) {
      final tailLen = size < sampleSize * 2 ? (size - sampleSize) : sampleSize;
      raf.setPositionSync(size - tailLen);
      tail = raf.readSync(tailLen);
    }

    final sizeBytes = utf8.encode(size.toString());
    final digest = sha1.convert(<int>[...sizeBytes, ...head, ...tail]);
    return digest.toString();
  } finally {
    raf.closeSync();
  }
}
