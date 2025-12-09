# 图片整理 (Image Organizer)

一款基于 PyQt6 开发的图片整理工具，帮助你快速浏览、分类和管理大量图片文件。

![Python](https://img.shields.io/badge/Python-3.11+-blue.svg)
![PyQt6](https://img.shields.io/badge/PyQt6-6.4+-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## ✨ 功能特性

### 图片浏览
- **缩略图预览** - 快速加载图片缩略图，支持异步加载避免卡顿
- **可调节大小** - 通过滑块自由调整缩略图尺寸（60-200px）
- **多选操作** - 支持 Ctrl/Cmd 多选和 Shift 范围选择

### 文件夹管理
- **文件夹导航** - 左侧显示所有子文件夹，点击即可切换
- **新建文件夹** - 一键创建新文件夹
- **重命名文件夹** - 重命名时自动重命名内部所有图片为 `文件夹名 (001).扩展名` 格式
- **删除到回收站** - 安全删除，文件移至系统回收站可恢复

### 拖拽整理
- **拖拽分类** - 将图片拖拽到左侧文件夹即可移动并自动重命名
- **批量操作** - 支持多选后批量拖拽
- **拖拽排序** - 在图片区域内拖拽可调整顺序

### 其他功能
- **在 Finder 中显示** - 右键菜单快速定位文件位置
- **刷新** - 一键刷新当前目录内容
- **返回** - 返回欢迎页重新选择文件夹

---

## 🚀 快速开始

### 安装

```bash
# 克隆项目
git clone <repository-url>
cd organimage

# 创建虚拟环境（推荐）
conda create -n organimage python=3.11
conda activate organimage

# 安装依赖
pip install -r requirements.txt
```

### 运行

```bash
python main.py
```

### 打包为应用程序

```bash
# 安装打包工具
pip install pyinstaller

# 打包（macOS 生成 .app，Windows 生成 .exe）
python build.py

# 输出位置：dist/图片整理.app
```

---

## 📖 操作指南

### 基本流程

1. **启动程序** - 运行后显示欢迎页面
2. **选择文件夹** - 点击「选择文件夹开始」按钮，选择包含图片的目录
3. **浏览图片** - 右侧显示当前目录的图片缩略图
4. **切换目录** - 点击左侧文件夹按钮切换到子目录
5. **整理图片** - 拖拽图片到目标文件夹完成分类

### 快捷操作

| 操作 | 说明 |
|------|------|
| **单击图片** | 选中图片 |
| **Ctrl/Cmd + 单击** | 多选/取消选中 |
| **Shift + 单击** | 范围选择 |
| **拖拽图片到文件夹** | 移动并自动重命名 |
| **右键图片** | 显示上下文菜单（重命名、删除、在 Finder 中显示） |
| **右键文件夹** | 显示上下文菜单（重命名、删除、在 Finder 中显示） |
| **双击文件夹** | 进入该文件夹 |

### 自动命名规则

当图片被移动到文件夹或文件夹被重命名时，内部图片会自动按以下格式重命名：

```
文件夹名 (001).jpg
文件夹名 (002).png
文件夹名 (003).webp
...
```

---

## 🗂️ 项目结构

```
organimage/
├── main.py                 # 程序入口
├── build.py                # 打包脚本
├── build.spec              # PyInstaller 配置
├── requirements.txt        # Python 依赖
├── assets/                 # 资源文件
│   ├── icon.png            # 应用图标
│   ├── icon.icns           # macOS 图标
│   └── icon.ico            # Windows 图标
└── src/
    ├── app.py              # 应用初始化
    ├── main_window.py      # 主窗口
    ├── constants.py        # 常量配置
    ├── styles.py           # UI 样式表
    ├── utils.py            # 工具函数
    ├── thumbnail_cache.py  # 缩略图缓存
    ├── pages/
    │   ├── welcome_page.py # 欢迎页
    │   └── browser_page.py # 浏览页
    └── widgets/
        ├── thumbnail.py    # 缩略图组件
        └── folder_button.py # 文件夹按钮组件
```

---

## 🖼️ 支持的图片格式

PNG, JPG, JPEG, GIF, BMP, WebP, TIFF, ICO, SVG

---

## 📋 系统要求

- **操作系统**: macOS 10.14+ / Windows 10+ / Linux
- **Python**: 3.11+
- **依赖**: PyQt6, qtawesome, send2trash

---

## 📄 License

MIT License
