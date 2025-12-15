import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Service for storing app configuration and recent folders
class StorageService {
  static const String _configFileName = 'config.json';
  static const int _maxRecentFolders = 10;

  static Future<void>? _pendingOperation;

  static Future<String> get _configPath async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/$_configFileName';
  }

  static Future<Map<String, dynamic>> _loadConfig() async {
    try {
      final path = await _configPath;
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      // Ignore errors, return empty config
    }
    return {};
  }

  static Future<void> _saveConfig(Map<String, dynamic> config) async {
    // Wait for any pending operation to complete
    while (_pendingOperation != null) {
      await _pendingOperation;
    }

    final completer = Completer<void>();
    _pendingOperation = completer.future;

    try {
      final path = await _configPath;
      final file = File(path);
      // Ensure parent directory exists
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await file.writeAsString(json.encode(config));
    } catch (e) {
      // Ignore errors
    } finally {
      _pendingOperation = null;
      completer.complete();
    }
  }

  /// Get list of recently opened folders
  static Future<List<String>> getRecentFolders() async {
    final config = await _loadConfig();
    final folders =
        (config['recent_folders'] as List<dynamic>?)?.cast<String>() ?? [];
    // Return all folders without checking existence
    // macOS sandbox may prevent access check for previously opened folders
    return folders.take(_maxRecentFolders).toList();
  }

  /// Add a folder to recent folders list
  static Future<void> addRecentFolder(String folderPath) async {
    final config = await _loadConfig();
    final folders =
        (config['recent_folders'] as List<dynamic>?)?.cast<String>().toList() ??
        [];

    // Remove if already exists
    folders.remove(folderPath);

    // Add to front
    folders.insert(0, folderPath);

    // Limit count
    config['recent_folders'] = folders.take(_maxRecentFolders).toList();
    await _saveConfig(config);
  }

  /// Clear all recent folders
  static Future<void> clearRecentFolders() async {
    final config = await _loadConfig();
    config['recent_folders'] = <String>[];
    await _saveConfig(config);
  }

  /// Get theme mode preference (null = system, 'light', 'dark')
  static Future<String?> getThemeMode() async {
    final config = await _loadConfig();
    return config['theme_mode'] as String?;
  }

  /// Set theme mode preference
  static Future<void> setThemeMode(String? mode) async {
    final config = await _loadConfig();
    config['theme_mode'] = mode;
    await _saveConfig(config);
  }

  /// Get language preference
  static Future<String?> getLanguage() async {
    final config = await _loadConfig();
    return config['language'] as String?;
  }

  /// Set language preference
  static Future<void> setLanguage(String language) async {
    final config = await _loadConfig();
    config['language'] = language;
    await _saveConfig(config);
  }

  /// Get theme color preference
  static Future<String?> getThemeColor() async {
    final config = await _loadConfig();
    return config['theme_color'] as String?;
  }

  /// Set theme color preference
  static Future<void> setThemeColor(String color) async {
    final config = await _loadConfig();
    config['theme_color'] = color;
    await _saveConfig(config);
  }

  /// Get thumbnail mode preference
  static Future<bool> getUseThumbnails() async {
    final config = await _loadConfig();
    return config['use_thumbnails'] as bool? ?? false;
  }

  /// Set thumbnail mode preference
  static Future<void> setUseThumbnails(bool enabled) async {
    final config = await _loadConfig();
    config['use_thumbnails'] = enabled;
    await _saveConfig(config);
  }

  static Future<void> clearThumbnailCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final root = Directory('${dir.path}/organimage_cache');
      if (!await root.exists()) return;

      final entities = root.listSync(followLinks: false);
      for (final entity in entities) {
        if (entity is! Directory) continue;
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('thumb_')) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {
            // Ignore errors
          }
        }
      }
    } catch (_) {
      // Ignore errors
    }
  }
}
