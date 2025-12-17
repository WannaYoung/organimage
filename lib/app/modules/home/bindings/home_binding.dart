import 'package:get/get.dart';

import '../controllers/home_controller.dart';

/// 主页模块绑定，注册依赖注入
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
  }
}
