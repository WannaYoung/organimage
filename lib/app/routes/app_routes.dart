part of 'app_pages.dart';

/// 路由名称常量
abstract class Routes {
  Routes._();
  static const home = _Paths.home;
  static const browser = _Paths.browser;
}

/// 路由路径常量
abstract class _Paths {
  _Paths._();
  static const home = '/home';
  static const browser = '/browser';
}
