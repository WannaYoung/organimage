part of 'app_pages.dart';

abstract class Routes {
  Routes._();
  static const home = _Paths.home;
  static const browser = _Paths.browser;
}

abstract class _Paths {
  _Paths._();
  static const home = '/home';
  static const browser = '/browser';
}
