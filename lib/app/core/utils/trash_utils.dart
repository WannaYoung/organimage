import 'dart:io';

(bool, String) movePathToTrash(String path) {
  if (!File(path).existsSync() && !Directory(path).existsSync()) {
    return (false, 'error_path_not_exist');
  }

  try {
    if (Platform.isMacOS) {
      final escaped = path.replaceAll('"', '\\"');
      final script =
          'tell application "Finder" to delete POSIX file "$escaped"';
      final result = Process.runSync('osascript', ['-e', script]);
      if (result.exitCode == 0) {
        return (true, 'success');
      }
      return (false, 'error_trash_failed');
    }

    if (Platform.isWindows) {
      final escaped = path.replaceAll("'", "''");
      final command =
          "\$shell = New-Object -ComObject Shell.Application; "
          "\$recycleBin = \$shell.Namespace(0xA); "
          "\$recycleBin.MoveHere('$escaped')";
      final result = Process.runSync('powershell', [
        '-NoProfile',
        '-Command',
        command,
      ]);
      if (result.exitCode == 0) {
        return (true, 'success');
      }
      return (false, 'error_trash_failed');
    }

    final result = Process.runSync('gio', ['trash', path]);
    if (result.exitCode == 0) {
      return (true, 'success');
    }
    return (false, 'error_trash_failed');
  } catch (e) {
    return (false, 'error_trash_failed');
  }
}
