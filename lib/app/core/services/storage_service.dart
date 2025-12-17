import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 存储服务，用于保存应用配置和最近打开的文件夹
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
      // 忽略错误，返回空配置
    }
    return {};
  }

  static Future<void> _saveConfig(Map<String, dynamic> config) async {
    // 等待任何待处理的操作完成
    while (_pendingOperation != null) {
      await _pendingOperation;
    }

    final completer = Completer<void>();
    _pendingOperation = completer.future;

    try {
      final path = await _configPath;
      final file = File(path);
      // 确保父目录存在
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await file.writeAsString(json.encode(config));
    } catch (e) {
      // 忽略错误
    } finally {
      _pendingOperation = null;
      completer.complete();
    }
  }

  /// 获取最近打开的文件夹列表
  static Future<List<String>> getRecentFolders() async {
    final config = await _loadConfig();
    final folders =
        (config['recent_folders'] as List<dynamic>?)?.cast<String>() ?? [];
    // 返回所有文件夹，不检查是否存在
    // macOS 沙盒可能会阻止对之前打开的文件夹进行访问检查
    return folders.take(_maxRecentFolders).toList();
  }

  /// 将文件夹添加到最近文件夹列表
  static Future<void> addRecentFolder(String folderPath) async {
    final config = await _loadConfig();
    final folders =
        (config['recent_folders'] as List<dynamic>?)?.cast<String>().toList() ??
        [];

    // 如果已存在则移除
    folders.remove(folderPath);

    // 添加到列表前端
    folders.insert(0, folderPath);

    // 限制数量
    config['recent_folders'] = folders.take(_maxRecentFolders).toList();
    await _saveConfig(config);
  }

  /// 清除所有最近文件夹
  static Future<void> clearRecentFolders() async {
    final config = await _loadConfig();
    config['recent_folders'] = <String>[];
    await _saveConfig(config);
  }

  /// 获取主题模式偏好（null = 跟随系统，'light'，'dark'）
  static Future<String?> getThemeMode() async {
    final config = await _loadConfig();
    return config['theme_mode'] as String?;
  }

  /// 设置主题模式偏好
  static Future<void> setThemeMode(String? mode) async {
    final config = await _loadConfig();
    config['theme_mode'] = mode;
    await _saveConfig(config);
  }

  /// 获取语言偏好
  static Future<String?> getLanguage() async {
    final config = await _loadConfig();
    return config['language'] as String?;
  }

  /// 设置语言偏好
  static Future<void> setLanguage(String language) async {
    final config = await _loadConfig();
    config['language'] = language;
    await _saveConfig(config);
  }

  /// 获取主题颜色偏好
  static Future<String?> getThemeColor() async {
    final config = await _loadConfig();
    return config['theme_color'] as String?;
  }

  /// 设置主题颜色偏好
  static Future<void> setThemeColor(String color) async {
    final config = await _loadConfig();
    config['theme_color'] = color;
    await _saveConfig(config);
  }

  /// 获取缩略图模式偏好
  static Future<bool> getUseThumbnails() async {
    final config = await _loadConfig();
    return config['use_thumbnails'] as bool? ?? false;
  }

  /// 设置缩略图模式偏好
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
            // 忽略错误
          }
        }
      }
    } catch (_) {
      // 忽略错误
    }
  }
}
