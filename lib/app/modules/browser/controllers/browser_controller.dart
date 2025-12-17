import 'dart:io';
import 'dart:async';

import 'package:get/get.dart';

import '../../../core/utils/toast_utils.dart';
import 'browser_directory_loader.dart';
import 'browser_file_ops.dart';
import 'browser_reorder_actions.dart';
import 'browser_selection_actions.dart';
import '../coordinators/reorder_coordinator.dart';
import '../coordinators/selection_coordinator.dart';
import '../services/directory_service.dart';
import '../services/file_operation_service.dart';
import '../services/renumber_service.dart';
import '../services/thumbnail_service.dart';

/// 浏览器主控制器，管理文件浏览、选择、排序等核心功能
class BrowserController extends GetxController {
  BrowserController({
    required this.directoryService,
    required this.fileOperationService,
    required this.renumberService,
    required this.thumbnailService,
  }) {
    _selectionCoordinator = SelectionCoordinator(
      selectedImages: selectedImages,
      imageFiles: imageFiles,
    );
    _reorderCoordinator = ReorderCoordinator(
      imageFiles: imageFiles,
      isReordering: isReordering,
      renumberService: renumberService,
      getCurrentFolderPath: () => currentPath.value,
      canReorderInCurrentFolder: () => canReorderInCurrentFolder,
      setLoading: ({required bool value, String? messageKey}) {
        isLoading.value = value;
        loadingMessageKey.value = value ? messageKey : null;
      },
      refreshAfterCommit: () {
        return _reloadAfterReorderCommit();
      },
      showError: (message) {
        showErrorToast(_formatErrorMessage(message));
      },
    );

    _directoryLoader = BrowserDirectoryLoader(
      directoryService: directoryService,
      thumbnailService: thumbnailService,
      rootPath: rootPath,
      currentPath: currentPath,
      subdirectories: subdirectories,
      folderFileCounts: folderFileCounts,
      folderPreviewImages: folderPreviewImages,
      imageFiles: imageFiles,
      useThumbnails: useThumbnails,
      isLoading: isLoading,
      loadingMessageKey: loadingMessageKey,
      clearSelection: () => clearSelection(),
      update: () => update(),
      preGenerateThumbnailsForCurrentFolder:
          _preGenerateThumbnailsForCurrentFolder,
    );

    _selectionActions = BrowserSelectionActions(
      selectedImages: selectedImages,
      imageFiles: imageFiles,
      selectionCoordinator: _selectionCoordinator,
      update: (ids) => update(ids),
    );

    _fileOps = BrowserFileOps(
      directoryService: directoryService,
      fileOperationService: fileOperationService,
      renumberService: renumberService,
      thumbnailService: thumbnailService,
      selectedImages: selectedImages,
      imageFiles: imageFiles,
      rootPath: rootPath,
      currentPath: currentPath,
      useThumbnails: useThumbnails,
      thumbnailSize: thumbnailSize,
      isLoading: isLoading,
      loadingMessageKey: loadingMessageKey,
      isAtRoot: () => isAtRoot,
      loadCurrentDirectory: () => loadCurrentDirectory(),
      clearImageCache: () => _directoryLoader.clearImageCache(),
      invalidateFolderCache: (folderPath) =>
          _directoryLoader.invalidateFolderCache(folderPath),
      clearSelection: () => clearSelection(),
      update: () => update(),
      formatErrorMessage: _formatErrorMessage,
    );

    _reorderActions = BrowserReorderActions(
      reorderCoordinator: _reorderCoordinator,
      isReordering: isReordering,
    );
  }

  final DirectoryService directoryService;
  final FileOperationService fileOperationService;
  final RenumberService renumberService;
  final ThumbnailService thumbnailService;

  late final SelectionCoordinator _selectionCoordinator;
  late final ReorderCoordinator _reorderCoordinator;

  late final BrowserDirectoryLoader _directoryLoader;
  late final BrowserSelectionActions _selectionActions;
  late final BrowserFileOps _fileOps;
  late final BrowserReorderActions _reorderActions;

  // 用户选择的根目录路径
  final Rx<String?> rootPath = Rx<String?>(null);

  // 当前目录路径（用于展示图片）
  final Rx<String?> currentPath = Rx<String?>(null);

  // 根目录下的子目录（始终展示根目录的子文件夹）
  final RxList<Directory> subdirectories = <Directory>[].obs;

  final RxMap<String, int> folderFileCounts = <String, int>{}.obs;
  final RxMap<String, String?> folderPreviewImages = <String, String?>{}.obs;

  // 当前选中文件夹中的图片文件
  final RxList<FileSystemEntity> imageFiles = <FileSystemEntity>[].obs;

  // 已选中的图片文件
  final RxList<String> selectedImages = <String>[].obs;

  // 缩略图大小
  final RxDouble thumbnailSize = 120.0.obs;

  // 优先使用缓存缩略图（默认关闭）
  final RxBool useThumbnails = false.obs;

  // 加载状态
  final RxBool isLoading = false.obs;

  final Rx<String?> loadingMessageKey = Rx<String?>(null);

  final RxBool isReordering = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    _directoryLoader.onInitFromArgs(args, setRootPath: setRootPath);
  }

  void setRootPath(String path) {
    _directoryLoader.setRootPath(
      path,
      loadCurrentDirectory: loadCurrentDirectory,
    );
  }

  void loadCurrentDirectory() {
    _directoryLoader.loadCurrentDirectory(
      refreshFolderMetaCacheAsync: (requestId) =>
          _refreshFolderMetaCacheAsync(requestId),
    );
  }

  Future<void> _reloadAfterReorderCommit() async {
    await _directoryLoader.reloadAfterReorderCommit(
      getFolderMeta: (folderPath) => directoryService.getFolderMeta(folderPath),
    );
  }

  Future<void> _refreshFolderMetaCacheAsync(int requestId) async {
    await _directoryLoader.refreshFolderMetaCacheAsync(
      requestId,
      getFolderMetas: (paths) => directoryService.getFolderMetas(paths),
    );
  }

  int getFolderFileCount(String folderPath) {
    return _directoryLoader.getFolderFileCount(folderPath);
  }

  String? getFolderPreviewImage(String folderPath) {
    return _directoryLoader.getFolderPreviewImage(folderPath);
  }

  void navigateToFolder(String folderPath) {
    _directoryLoader.navigateToFolder(
      folderPath,
      loadCurrentDirectory: loadCurrentDirectory,
    );
  }

  void goToHome() {
    Get.back();
  }

  void toggleImageSelection(String imagePath) {
    _selectionActions.toggleImageSelection(imagePath);
  }

  void selectSingleImage(String imagePath) {
    _selectionActions.selectSingleImage(imagePath);
  }

  void selectRangeTo(String imagePath, {required bool additive}) {
    _selectionActions.selectRangeTo(imagePath, additive: additive);
  }

  void handleImageTapSelection(
    String imagePath, {
    required bool isCtrlPressed,
    required bool isShiftPressed,
  }) {
    _selectionActions.handleImageTapSelection(
      imagePath,
      isCtrlPressed: isCtrlPressed,
      isShiftPressed: isShiftPressed,
    );
  }

  void clearSelection() {
    _selectionActions.clearSelection();
  }

  String _formatErrorMessage(String keyOrMessage) {
    if (keyOrMessage.startsWith('error_')) {
      return keyOrMessage.tr;
    }
    return keyOrMessage;
  }

  Future<void> importExternalImagesToCurrentFolder(List<String> paths) async {
    return _fileOps.importExternalImagesToCurrentFolder(paths);
  }

  void selectAllImages() {
    _selectionActions.selectAllImages();
  }

  void applyDragSelection(
    List<String> paths, {
    required bool additive,
    List<String>? baseSelection,
  }) {
    _selectionActions.applyDragSelection(
      paths,
      additive: additive,
      baseSelection: baseSelection,
    );
  }

  Future<void> moveSelectedToFolder(String folderPath) async {
    return _fileOps.moveSelectedToFolder(folderPath);
  }

  /// 将选中的图片移动到根目录（保持原文件名）
  Future<void> moveSelectedToRootFolder() async {
    return _fileOps.moveSelectedToRootFolder();
  }

  Future<void> deleteSelectedImages() async {
    return _fileOps.deleteSelectedImages();
  }

  Future<void> createNewFolder(String folderName) async {
    return _fileOps.createNewFolder(folderName);
  }

  void setThumbnailSize(double size) {
    _fileOps.setThumbnailSize(size);
  }

  void setUseThumbnails(bool enabled) {
    _fileOps.setUseThumbnails(enabled);
  }

  String get currentFolderName {
    return _directoryLoader.getCurrentFolderName();
  }

  bool get isAtRoot {
    return currentPath.value == rootPath.value;
  }

  bool get canReorderInCurrentFolder {
    return !isAtRoot && currentPath.value != null;
  }

  void startReorder(String imagePath) {
    _reorderActions.startReorder(imagePath);
  }

  void previewReorderTo(String targetImagePath) {
    _reorderActions.previewReorderTo(targetImagePath);
  }

  void cancelReorderPreview() {
    _reorderActions.cancelReorderPreview();
  }

  void commitReorderAndRenumber() {
    _reorderActions.commitReorderAndRenumber();
  }

  void handleReorderDragEnd({required bool wasAccepted}) {
    _reorderActions.handleReorderDragEnd(wasAccepted: wasAccepted);
  }

  void endReorderAfterAcceptedDrop() {
    _reorderActions.endReorderAfterAcceptedDrop();
  }

  // 在系统文件管理器中打开文件或文件夹
  Future<void> openInFinder(String path) async {
    return _fileOps.openInFinder(path);
  }

  // 重命名单张图片
  Future<void> renameImage(String imagePath, String newName) async {
    return _fileOps.renameImage(imagePath, newName);
  }

  // 删除单张图片
  // 若在子文件夹中，删除后对剩余文件重新编号
  Future<void> deleteImage(String imagePath) async {
    return _fileOps.deleteImage(imagePath);
  }

  // 根据路径删除文件夹
  Future<void> deleteFolderByPath(String folderPath) async {
    return _fileOps.deleteFolderByPath(folderPath);
  }

  // 重命名文件夹及其所有内容
  Future<void> renameFolderWithContents(
    String folderPath,
    String newName,
  ) async {
    return _fileOps.renameFolderWithContents(folderPath, newName);
  }

  Future<void> _preGenerateThumbnailsForCurrentFolder() async {
    final folder = currentPath.value;
    if (folder == null) return;
    final paths = imageFiles.map((e) => e.path).toList(growable: false);
    thumbnailService.clearResolvedCache();
    await thumbnailService.preGenerateForFolder(
      folder,
      paths,
      onProgress: () {
        if (useThumbnails.value) {
          update();
        }
      },
    );
  }
}
