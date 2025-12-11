# OrganImage

跨平台桌面图片整理应用，支持拖拽排序、批量重命名和网格预览。

## 功能特性

- **拖拽排序** - 通过拖拽轻松调整图片顺序
- **批量重命名** - 一次性重命名多张图片
- **网格预览** - 可自定义的网格布局查看图片
- **跨平台** - 支持 macOS、Windows 和 Linux
- **主题切换** - 根据系统偏好自动切换深色/浅色主题
- **多语言** - 支持英文、简体中文和繁体中文
- **最近文件夹** - 快速访问最近打开的文件夹

## 截图

<!-- 在此添加截图 -->

## 技术栈

- **框架**: Flutter 3.9+
- **状态管理**: GetX
- **UI 组件**: ForUI
- **图片查看**: photo_view
- **文件处理**: file_picker, cross_file, desktop_drop
- **窗口管理**: window_manager

## 快速开始

### 环境要求

- Flutter SDK ^3.9.0
- Dart SDK

### 安装

1. 克隆仓库：
   ```bash
   git clone https://github.com/WannaYoung/organimage.git
   cd organimage
   ```

2. 安装依赖：
   ```bash
   flutter pub get
   ```

3. 运行应用：
   ```bash
   flutter run -d macos   # macOS
   flutter run -d windows # Windows
   flutter run -d linux   # Linux
   ```

### 构建

```bash
flutter build macos   # 构建 macOS 版本
flutter build windows # 构建 Windows 版本
flutter build linux   # 构建 Linux 版本
```

## 项目结构

```
lib/
├── main.dart              # 应用入口
└── app/
    ├── core/              # 核心工具、主题、国际化
    ├── modules/
    │   ├── home/          # 首页模块
    │   └── browser/       # 图片浏览模块
    └── routes/            # 路由配置
```

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 贡献

欢迎贡献代码！请随时提交 Pull Request。
