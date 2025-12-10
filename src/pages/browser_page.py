"""
File browser page with folder navigation and thumbnail grid.
Optimized for performance with debouncing and lazy loading.
"""

import os
from typing import Callable, Optional, List, Set

from PyQt6.QtCore import Qt, QTimer, QSize
from PyQt6.QtGui import QFont, QKeyEvent
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QFrame, QScrollArea, QSlider, QGridLayout, QSizePolicy,
    QInputDialog, QMessageBox, QApplication, QSplitter, QFileDialog
)

try:
    import qtawesome as qta
    HAS_QTAWESOME = True
except ImportError:
    HAS_QTAWESOME = False

from ..constants import (
    DEFAULT_THUMB_SIZE, MIN_THUMB_SIZE, MAX_THUMB_SIZE,
    FOLDER_BUTTON_SIZE, FOLDER_BUTTON_SPACING, FOLDER_MIN_COLUMNS,
    FILES_GRID_SPACING, FILES_GRID_MARGIN,
    RESIZE_DEBOUNCE_MS, SLIDER_DEBOUNCE_MS
)
from ..styles import (
    BACK_BUTTON_STYLE, REFRESH_BUTTON_STYLE, ADD_FOLDER_BUTTON_STYLE,
    FOLDERS_FRAME_STYLE, FILES_FRAME_STYLE, SIZE_SLIDER_STYLE,
    SCROLL_AREA_STYLE, SPLITTER_STYLE, HEADER_LABEL_STYLE, PATH_LABEL_STYLE,
    CONTEXT_MENU_STYLE,
    DARK_BACK_BUTTON_STYLE, DARK_FOLDERS_FRAME_STYLE, DARK_FILES_FRAME_STYLE,
    DARK_SIZE_SLIDER_STYLE, DARK_SCROLL_AREA_STYLE, DARK_SPLITTER_STYLE,
    DARK_HEADER_LABEL_STYLE, DARK_PATH_LABEL_STYLE, DARK_CONTEXT_MENU_STYLE
)
from ..theme_manager import get_theme_manager
from ..utils import (
    get_image_files, get_subdirectories, 
    move_file_to_folder, rename_folder_with_contents, create_folder,
    delete_file, delete_folder, rename_file, open_in_finder,
    reorder_files_by_list, add_recent_folder
)
from ..widgets import ThumbnailWidget, FolderButton, ImagePreviewDialog, SelectionContainer


class FileBrowserPage(QWidget):
    """Main file browser with folder navigation and file thumbnails."""
    
    def __init__(self, on_back: Callable[[], None]):
        super().__init__()
        self.on_back = on_back
        self.root_path = None
        self.current_path = None
        self.thumb_size = DEFAULT_THUMB_SIZE
        self.folder_buttons = []
        self.thumbnail_widgets = []
        self.selected_files: Set[str] = set()  # Track selected file paths
        self._last_clicked_index: Optional[int] = None  # For shift-select range
        self._is_dark = False
        self._current_files = []
        
        # Debounce timers
        self._resize_timer: Optional[QTimer] = None
        self._slider_timer: Optional[QTimer] = None
        self._pending_size: Optional[int] = None
        
        self._init_ui()
    
    def _init_ui(self):
        """Initialize the UI components."""
        layout = QVBoxLayout(self)
        layout.setSpacing(8)
        layout.setContentsMargins(12, 12, 12, 12)
        
        # Top bar
        self._create_top_bar(layout)
        
        # Splitter for folders and files
        self.splitter = QSplitter(Qt.Orientation.Vertical)
        self.splitter.setHandleWidth(8)
        self.splitter.setStyleSheet(SPLITTER_STYLE)
        
        # Create folders and files sections
        self._create_folders_section()
        self._create_files_section()
        
        # Add to splitter
        self.splitter.addWidget(self.folders_frame)
        self.splitter.addWidget(self.files_frame)
        
        # Set initial sizes: 1/3 for folders, 2/3 for files
        self.splitter.setStretchFactor(0, 1)
        self.splitter.setStretchFactor(1, 2)
        
        # Connect splitter moved signal to relayout
        self.splitter.splitterMoved.connect(self._on_splitter_moved)
        
        layout.addWidget(self.splitter, 1)
    
    def _create_top_bar(self, parent_layout: QVBoxLayout):
        """Create the top navigation bar."""
        # Top bar container with background
        top_bar_frame = QFrame()
        top_bar_frame.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #FFFFFF, stop:1 #F8FAFC);
                border: 1px solid #E2E8F0;
                border-radius: 12px;
                padding: 4px;
            }
        """)
        top_bar_frame.setFixedHeight(56)
        
        top_bar = QHBoxLayout(top_bar_frame)
        top_bar.setContentsMargins(8, 4, 8, 4)
        top_bar.setSpacing(12)
        
        # Back button with icon
        self.back_btn = QPushButton("  返回")
        if HAS_QTAWESOME:
            self.back_btn.setIcon(qta.icon('fa5s.arrow-left', color='#64748B'))
            self.back_btn.setIconSize(QSize(14, 14))
        self.back_btn.setFixedHeight(40)
        self.back_btn.setStyleSheet(BACK_BUTTON_STYLE)
        self.back_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.back_btn.clicked.connect(self.on_back)
        
        # Path label with styled background
        self.path_label = QLabel("")
        self.path_label.setStyleSheet(PATH_LABEL_STYLE)
        
        # Open folder button - switch root directory
        self.open_folder_btn = QPushButton()
        if HAS_QTAWESOME:
            self.open_folder_btn.setIcon(qta.icon('fa5s.folder-open', color='#5B7FFF'))
            self.open_folder_btn.setIconSize(QSize(16, 16))
        else:
            self.open_folder_btn.setText("📂")
        self.open_folder_btn.setFixedSize(40, 40)
        self.open_folder_btn.setStyleSheet(BACK_BUTTON_STYLE)
        self.open_folder_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.open_folder_btn.setToolTip("切换根目录")
        self.open_folder_btn.clicked.connect(self._switch_root_folder)
        
        # Refresh button
        self.refresh_btn = QPushButton()
        if HAS_QTAWESOME:
            self.refresh_btn.setIcon(qta.icon('fa5s.sync-alt', color='white'))
            self.refresh_btn.setIconSize(QSize(16, 16))
        else:
            self.refresh_btn.setText("↻")
        self.refresh_btn.setFixedSize(40, 40)
        self.refresh_btn.setStyleSheet(REFRESH_BUTTON_STYLE)
        self.refresh_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.refresh_btn.clicked.connect(self.refresh_view)
        
        top_bar.addWidget(self.back_btn)
        top_bar.addWidget(self.path_label, 1)
        top_bar.addWidget(self.open_folder_btn)
        top_bar.addWidget(self.refresh_btn)
        
        parent_layout.addWidget(top_bar_frame)
    
    def _create_folders_section(self):
        """Create the folders section with vertical grid layout."""
        self.folders_frame = QFrame()
        self.folders_frame.setStyleSheet(FOLDERS_FRAME_STYLE)
        self.folders_frame.setMinimumHeight(80)
        
        folders_main_layout = QVBoxLayout(self.folders_frame)
        folders_main_layout.setContentsMargins(8, 6, 8, 6)
        folders_main_layout.setSpacing(4)
        
        # Header with title and add button
        folders_header = QHBoxLayout()
        folders_header.setContentsMargins(4, 4, 4, 4)
        folders_header.setSpacing(6)
        
        # Folder icon
        if HAS_QTAWESOME:
            folders_icon = QLabel()
            folders_icon.setPixmap(qta.icon('fa5s.folder', color='#5B7FFF').pixmap(QSize(16, 16)))
            folders_header.addWidget(folders_icon)
        
        self.folders_title_label = QLabel("文件夹")
        self.folders_title_label.setStyleSheet(HEADER_LABEL_STYLE)
        
        self.add_folder_btn = QPushButton()
        if HAS_QTAWESOME:
            self.add_folder_btn.setIcon(qta.icon('fa5s.plus', color='white'))
            self.add_folder_btn.setIconSize(QSize(12, 12))
        else:
            self.add_folder_btn.setText("+")
        self.add_folder_btn.setFixedSize(28, 28)
        self.add_folder_btn.setStyleSheet(ADD_FOLDER_BUTTON_STYLE)
        self.add_folder_btn.setToolTip("新建文件夹")
        self.add_folder_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.add_folder_btn.clicked.connect(self._add_folder)
        
        folders_header.addWidget(self.folders_title_label)
        folders_header.addStretch()
        folders_header.addWidget(self.add_folder_btn)
        folders_main_layout.addLayout(folders_header)
        
        # Folders scroll area with grid
        self.folders_scroll = QScrollArea()
        self.folders_scroll.setWidgetResizable(True)
        self.folders_scroll.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )
        self.folders_scroll.setVerticalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAsNeeded
        )
        self.folders_scroll.setStyleSheet(SCROLL_AREA_STYLE)
        self.folders_scroll.viewport().setStyleSheet("background: transparent;")
        
        self.folders_container = QWidget()
        self.folders_container.setStyleSheet("background: transparent; border: none;")
        self.folders_grid = QGridLayout(self.folders_container)
        self.folders_grid.setAlignment(
            Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignLeft
        )
        self.folders_grid.setSpacing(6)
        self.folders_grid.setContentsMargins(4, 4, 4, 4)
        self.folders_scroll.setWidget(self.folders_container)
        
        folders_main_layout.addWidget(self.folders_scroll, 1)
    
    def _create_files_section(self):
        """Create the files display section."""
        self.files_frame = QFrame()
        self.files_frame.setStyleSheet(FILES_FRAME_STYLE)
        self.files_frame.setMinimumHeight(100)
        
        files_layout = QVBoxLayout(self.files_frame)
        files_layout.setContentsMargins(8, 6, 8, 6)
        
        # Files header
        files_header = QHBoxLayout()
        files_header.setContentsMargins(4, 4, 4, 4)
        files_header.setSpacing(6)
        
        # Image icon
        if HAS_QTAWESOME:
            files_icon = QLabel()
            files_icon.setPixmap(qta.icon('fa5s.images', color='#5B7FFF').pixmap(QSize(16, 16)))
            files_header.addWidget(files_icon)
        
        self.files_title = QLabel("图片")
        self.files_title.setStyleSheet(HEADER_LABEL_STYLE)
        
        # Thumbnail size slider with label
        size_label = QLabel("尺寸")
        size_label.setStyleSheet("color: #64748B; font-size: 12px;")
        
        self.size_slider = QSlider(Qt.Orientation.Horizontal)
        self.size_slider.setMinimum(MIN_THUMB_SIZE)
        self.size_slider.setMaximum(MAX_THUMB_SIZE)
        self.size_slider.setValue(self.thumb_size)
        self.size_slider.setFixedWidth(100)
        self.size_slider.setStyleSheet(SIZE_SLIDER_STYLE)
        self.size_slider.valueChanged.connect(self._on_size_changed)
        
        files_header.addWidget(self.files_title)
        files_header.addStretch()
        files_header.addWidget(size_label)
        files_header.addWidget(self.size_slider)
        
        files_layout.addLayout(files_header)
        
        # Files scroll area with grid
        self.files_scroll = QScrollArea()
        self.files_scroll.setWidgetResizable(True)
        self.files_scroll.setStyleSheet(SCROLL_AREA_STYLE)
        self.files_scroll.viewport().setStyleSheet("background: transparent;")
        
        self.files_container = SelectionContainer()
        self.files_container.set_thumbnail_provider(self._get_thumbnail_widgets)
        self.files_container.set_selection_handler(self._on_rubber_band_selection)
        self.files_grid = QGridLayout(self.files_container)
        self.files_grid.setSpacing(6)
        self.files_grid.setContentsMargins(4, 4, 4, 4)
        self.files_grid.setAlignment(
            Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignLeft
        )
        self.files_scroll.setWidget(self.files_container)
        
        files_layout.addWidget(self.files_scroll, 1)
    
    def set_root_path(self, path: str):
        """Set the root path and load contents."""
        self.root_path = path
        self.current_path = path
        # Save to recent folders
        add_recent_folder(path)
        self.refresh_view()
    
    def _switch_root_folder(self):
        """Open folder dialog to switch root directory."""
        from pathlib import Path
        folder = QFileDialog.getExistingDirectory(
            self,
            "选择新的根目录",
            self.root_path or str(Path.home()),
            QFileDialog.Option.ShowDirsOnly
        )
        if folder:
            self.set_root_path(folder)
    
    def navigate_to(self, path: str):
        """Navigate to a specific folder."""
        self.current_path = path
        self.refresh_view()
    
    def refresh_view(self):
        """Refresh folders and files display."""
        if not self.current_path:
            return
        
        # Update path label
        rel_path = os.path.relpath(self.current_path, self.root_path)
        if rel_path == ".":
            self.path_label.setText(self.root_path)
        else:
            self.path_label.setText(f"{self.root_path} / {rel_path}")
        
        self._load_folders()
        self._load_files()
    
    def _load_folders(self):
        """Load and display folder buttons in grid layout."""
        # Clear existing with proper cleanup
        for btn in self.folder_buttons:
            btn.cleanup()
            btn.deleteLater()
        self.folder_buttons.clear()
        
        # Clear grid layout
        while self.folders_grid.count():
            item = self.folders_grid.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        
        # Calculate columns based on scroll area width
        folder_size = FOLDER_BUTTON_SIZE + FOLDER_BUTTON_SPACING + 4
        available_width = self.folders_scroll.width() - 20
        cols = max(1, available_width // folder_size)
        if cols < FOLDER_MIN_COLUMNS:
            cols = FOLDER_MIN_COLUMNS
        
        # Collect all folders (root + subfolders)
        all_folders = []
        
        # Add root button
        root_btn = FolderButton(self.root_path, is_root=True)
        root_btn.folder_clicked.connect(self.navigate_to)
        root_btn.folder_selected.connect(self._on_folder_selected)
        root_btn.open_source_requested.connect(self._open_source)
        root_btn.apply_theme(self._is_dark)
        all_folders.append(root_btn)
        self.folder_buttons.append(root_btn)
        
        # Get subfolders from root
        for folder_path in get_subdirectories(self.root_path):
            folder_btn = FolderButton(folder_path)
            folder_btn.folder_clicked.connect(self.navigate_to)
            folder_btn.folder_selected.connect(self._on_folder_selected)
            folder_btn.rename_requested.connect(self._rename_folder)
            folder_btn.delete_requested.connect(self._delete_folder)
            folder_btn.open_source_requested.connect(self._open_source)
            folder_btn.files_dropped.connect(self._handle_file_drop)
            folder_btn.apply_theme(self._is_dark)
            all_folders.append(folder_btn)
            self.folder_buttons.append(folder_btn)
        
        # Add to grid
        for i, btn in enumerate(all_folders):
            row = i // cols
            col = i % cols
            self.folders_grid.addWidget(btn, row, col)
        
        # Update folders title with count
        self.folders_title_label.setText(f"文件夹 ({len(all_folders)})")
        
        # Set selected state for current folder
        for btn in self.folder_buttons:
            btn.selected = (btn.folder_path == self.current_path)
    
    def _load_files(self):
        """Load and display file thumbnails."""
        # Clean up existing thumbnails properly
        for widget in self.thumbnail_widgets:
            widget.cleanup()  # Cancel any pending loaders
        
        # Process events to let cancelled threads finish
        QApplication.processEvents()
        
        # Now safe to delete widgets
        for widget in self.thumbnail_widgets:
            widget.deleteLater()
        self.thumbnail_widgets.clear()
        
        # Clear grid
        while self.files_grid.count():
            item = self.files_grid.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        
        # Process events again to ensure cleanup
        QApplication.processEvents()
        
        # Get image files from current directory
        files = get_image_files(self.current_path)
        
        # Update title with count
        self.files_title.setText(f"图片 ({len(files)})")
        
        # Calculate columns - use tighter spacing
        cols = max(1, (self.files_scroll.width() - 20) // (self.thumb_size + 12))
        if cols < 1:
            cols = 4  # Default
        
        # Store current file list for preview navigation
        self._current_files = files
        
        # Create thumbnails
        for i, file_path in enumerate(files):
            thumb = ThumbnailWidget(file_path, self.thumb_size, self.current_path, self.root_path)
            thumb.set_selection_provider(self._get_selected_files)
            thumb.clicked.connect(self._on_thumb_clicked)
            thumb.ctrl_clicked.connect(self._on_thumb_ctrl_clicked)
            thumb.shift_clicked.connect(self._on_thumb_shift_clicked)
            thumb.drag_started.connect(self._on_drag_started)
            thumb.open_source_requested.connect(self._open_source)
            thumb.delete_requested.connect(self._delete_file)
            thumb.rename_requested.connect(self._rename_file)
            thumb.reorder_requested.connect(self._on_reorder_requested)
            thumb.double_clicked.connect(self._on_thumb_double_clicked)
            # Apply current theme
            thumb.apply_theme(self._is_dark)
            row = i // cols
            col = i % cols
            self.files_grid.addWidget(thumb, row, col)
            self.thumbnail_widgets.append(thumb)
    
    def _handle_file_drop(self, file_paths: List[str], folder_path: str):
        """Handle files dropped onto a folder - supports batch move."""
        success_count = 0
        failed_files = []
        
        for file_path in file_paths:
            success, result = move_file_to_folder(file_path, folder_path)
            if success:
                success_count += 1
            else:
                failed_files.append(os.path.basename(file_path))
        
        # Clear selection after move
        self.selected_files.clear()
        self._last_clicked_index = None
        
        # Update folder button counts
        for btn in self.folder_buttons:
            btn.update_count()
        self._load_files()
        
        if failed_files:
            QMessageBox.warning(
                self, "部分失败",
                f"成功移动 {success_count} 个文件\n失败: {', '.join(failed_files[:5])}{'...' if len(failed_files) > 5 else ''}"
            )
    
    def _on_size_changed(self, value: int):
        """Handle thumbnail size slider change with debouncing."""
        self._pending_size = value
        
        # Debounce: only apply after user stops sliding
        if self._slider_timer is None:
            self._slider_timer = QTimer()
            self._slider_timer.setSingleShot(True)
            self._slider_timer.timeout.connect(self._apply_size_change)
        
        self._slider_timer.start(SLIDER_DEBOUNCE_MS)
    
    def _apply_size_change(self):
        """Actually apply the size change after debounce."""
        if self._pending_size is None:
            return
        
        value = self._pending_size
        self._pending_size = None
        self.thumb_size = value
        
        # Update all thumbnails
        for thumb in self.thumbnail_widgets:
            thumb.update_size(value)
        
        # Recalculate grid layout
        self._relayout_files_grid()
    
    def _add_folder(self):
        """Add a new folder in root directory."""
        name, ok = QInputDialog.getText(self, "新建文件夹", "请输入文件夹名称:")
        if ok and name:
            success, result = create_folder(self.root_path, name)
            if success:
                self._load_folders()
            else:
                QMessageBox.warning(self, "错误", result)
    
    def _rename_folder(self, folder_path: str):
        """Rename a folder and its contents."""
        old_name = os.path.basename(folder_path)
        new_name, ok = QInputDialog.getText(
            self, "重命名文件夹", "请输入新名称:", text=old_name
        )
        
        if ok and new_name and new_name != old_name:
            success, result = rename_folder_with_contents(folder_path, new_name)
            
            if success:
                # Update current path if we're in the renamed folder
                if self.current_path == folder_path:
                    self.current_path = result
                self.refresh_view()
            else:
                QMessageBox.warning(self, "错误", f"重命名失败: {result}")
    
    def _delete_folder(self, folder_path: str):
        """Delete a folder after confirmation."""
        folder_name = os.path.basename(folder_path)
        reply = QMessageBox.question(
            self, "确认删除",
            f"确定要删除文件夹 '{folder_name}' 及其所有内容吗？\n\n此操作不可撤销！",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply == QMessageBox.StandardButton.Yes:
            success, result = delete_folder(folder_path)
            if success:
                # If we're in the deleted folder, go back to root
                if self.current_path == folder_path:
                    self.current_path = self.root_path
                self.refresh_view()
            else:
                QMessageBox.warning(self, "错误", f"删除失败: {result}")
    
    def _delete_file(self, file_path: str):
        """Delete a file after confirmation."""
        file_name = os.path.basename(file_path)
        reply = QMessageBox.question(
            self, "确认删除",
            f"确定要删除文件 '{file_name}' 吗？\n\n此操作不可撤销！",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply == QMessageBox.StandardButton.Yes:
            success, result = delete_file(file_path)
            if success:
                self._load_files()
                # Update folder counts
                for btn in self.folder_buttons:
                    btn.update_count()
            else:
                QMessageBox.warning(self, "错误", f"删除失败: {result}")
    
    def _rename_file(self, file_path: str):
        """Rename a file - only edit name part, keep extension."""
        old_name = os.path.basename(file_path)
        name_part, ext = os.path.splitext(old_name)
        
        new_name_part, ok = QInputDialog.getText(
            self, "重命名文件", f"请输入新文件名 (扩展名: {ext}):", text=name_part
        )
        
        if ok and new_name_part and new_name_part != name_part:
            new_name = new_name_part + ext
            success, result = rename_file(file_path, new_name)
            if success:
                self._load_files()
            else:
                QMessageBox.warning(self, "错误", f"重命名失败: {result}")
    
    def _open_source(self, path: str):
        """Open file or folder in system file manager."""
        success, result = open_in_finder(path)
        if not success:
            QMessageBox.warning(self, "错误", f"无法打开: {result}")
    
    def _on_thumb_double_clicked(self, file_path: str):
        """Handle double click on thumbnail - open image preview."""
        if hasattr(self, '_current_files') and self._current_files:
            dialog = ImagePreviewDialog(file_path, self._current_files, self)
            dialog.exec()
    
    def _delete_selected_files(self):
        """Delete all selected files after confirmation."""
        if not self.selected_files:
            return
        
        count = len(self.selected_files)
        reply = QMessageBox.question(
            self, "确认删除",
            f"确定要删除选中的 {count} 张图片吗？\n\n文件将移至回收站。",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply == QMessageBox.StandardButton.Yes:
            success_count = 0
            failed_files = []
            
            for file_path in list(self.selected_files):
                success, result = delete_file(file_path)
                if success:
                    success_count += 1
                else:
                    failed_files.append(os.path.basename(file_path))
            
            # Clear selection
            self.selected_files.clear()
            self._last_clicked_index = None
            
            # Reload files
            self._load_files()
            
            # Update folder counts
            for btn in self.folder_buttons:
                btn.update_count()
            
            if failed_files:
                QMessageBox.warning(
                    self, "部分失败",
                    f"成功删除 {success_count} 个文件\n失败: {', '.join(failed_files[:5])}{'...' if len(failed_files) > 5 else ''}"
                )
    
    def _on_reorder_requested(self, dragged_path: str, target_path: str):
        """Handle file reorder request - move dragged file before target."""
        # Get current file list
        current_files = [thumb.file_path for thumb in self.thumbnail_widgets]
        
        if dragged_path not in current_files or target_path not in current_files:
            return
        
        # Remove dragged file from list
        current_files.remove(dragged_path)
        
        # Find target position and insert
        target_idx = current_files.index(target_path)
        current_files.insert(target_idx, dragged_path)
        
        # Get folder name for renaming
        folder_name = os.path.basename(self.current_path)
        
        # Reorder files by renaming
        success, result = reorder_files_by_list(current_files, folder_name)
        
        if success:
            # Clear selection and reload
            self._clear_selection()
            self._load_files()
            # Update folder counts
            for btn in self.folder_buttons:
                btn.update_count()
        else:
            QMessageBox.warning(self, "错误", f"排序失败: {result}")
    
    # ========== Selection Management ==========

    def _on_folder_selected(self, folder_path: str):
        """Handle folder selection - clear file selection, select folder."""
        # Clear file selection
        self._clear_selection()

        # Clear folder selection and select clicked one
        for btn in self.folder_buttons:
            btn.selected = (btn.folder_path == folder_path)

    def _clear_selection(self):
        """Clear all selections."""
        for thumb in self.thumbnail_widgets:
            thumb.selected = False
        self.selected_files.clear()
        self._update_title()

    def _update_title(self):
        """Update files title with selection count."""
        total = len(self.thumbnail_widgets)
        selected = len(self.selected_files)
        if selected > 0:
            self.files_title.setText(f"图片 ({total}) - 已选 {selected}")
        else:
            self.files_title.setText(f"图片 ({total})")
    
    def _get_thumb_index(self, file_path: str) -> int:
        """Get index of thumbnail by file path."""
        for i, thumb in enumerate(self.thumbnail_widgets):
            if thumb.file_path == file_path:
                return i
        return -1
    
    def _on_thumb_clicked(self, file_path: str):
        """Handle normal click - select only this item, or keep selection if clicking selected item."""
        # If clicking on an already selected item, don't clear selection
        # This allows dragging multiple selected files
        if file_path in self.selected_files:
            # Just update last clicked index for potential drag
            idx = self._get_thumb_index(file_path)
            if idx >= 0:
                self._last_clicked_index = idx
            return
        
        # Clicking on unselected item - clear and select only this one
        self._clear_selection()
        idx = self._get_thumb_index(file_path)
        if idx >= 0:
            self.thumbnail_widgets[idx].selected = True
            self.selected_files.add(file_path)
            self._last_clicked_index = idx
        self._update_title()
    
    def _on_thumb_ctrl_clicked(self, file_path: str):
        """Handle Ctrl+click - toggle selection."""
        idx = self._get_thumb_index(file_path)
        if idx >= 0:
            thumb = self.thumbnail_widgets[idx]
            if file_path in self.selected_files:
                thumb.selected = False
                self.selected_files.discard(file_path)
            else:
                thumb.selected = True
                self.selected_files.add(file_path)
            self._last_clicked_index = idx
        self._update_title()
    
    def _on_thumb_shift_clicked(self, file_path: str):
        """Handle Shift+click - range selection."""
        idx = self._get_thumb_index(file_path)
        if idx < 0:
            return
        
        start = self._last_clicked_index if self._last_clicked_index is not None else 0
        end = idx
        if start > end:
            start, end = end, start
        
        # Select range
        for i in range(start, end + 1):
            thumb = self.thumbnail_widgets[i]
            thumb.selected = True
            self.selected_files.add(thumb.file_path)
        
        self._update_title()
    
    def _on_drag_started(self, file_path: str):
        """Handle drag start - ensure dragged item is selected and prepare multi-file drag."""
        # If dragging an unselected item, select only it
        if file_path not in self.selected_files:
            self._clear_selection()
            idx = self._get_thumb_index(file_path)
            if idx >= 0:
                self.thumbnail_widgets[idx].selected = True
                self.selected_files.add(file_path)
    
    def _get_selected_files(self) -> Set[str]:
        """Get the set of selected file paths for drag operations."""
        return self.selected_files
    
    def _get_thumbnail_widgets(self) -> List:
        """Get list of thumbnail widgets for rubber band selection."""
        return self.thumbnail_widgets
    
    def _on_rubber_band_selection(self, indices: List[int], clear: bool = True):
        """Handle rubber band selection changes."""
        if clear:
            # Clear existing selection first
            for thumb in self.thumbnail_widgets:
                thumb.selected = False
            self.selected_files.clear()
        
        # Select widgets at given indices
        for idx in indices:
            if 0 <= idx < len(self.thumbnail_widgets):
                thumb = self.thumbnail_widgets[idx]
                thumb.selected = True
                self.selected_files.add(thumb.file_path)
        
        self._update_title()
    
    def _relayout_folders_grid(self):
        """Recalculate and apply folders grid layout."""
        if not self.folder_buttons:
            return
        
        folder_size = FOLDER_BUTTON_SIZE + FOLDER_BUTTON_SPACING
        available_width = self.folders_scroll.width() - 20
        cols = max(FOLDER_MIN_COLUMNS, available_width // folder_size)
        
        for i, btn in enumerate(self.folder_buttons):
            self.folders_grid.removeWidget(btn)
            row = i // cols
            col = i % cols
            self.folders_grid.addWidget(btn, row, col)
    
    def _relayout_files_grid(self):
        """Recalculate and apply files grid layout."""
        if not self.thumbnail_widgets:
            return
        
        cols = max(1, (self.files_scroll.width() - 20) // (self.thumb_size + FILES_GRID_SPACING * 2))
        
        for i, thumb in enumerate(self.thumbnail_widgets):
            self.files_grid.removeWidget(thumb)
            row = i // cols
            col = i % cols
            self.files_grid.addWidget(thumb, row, col)
    
    def _relayout_all(self):
        """Relayout both folders and files grids."""
        self._relayout_folders_grid()
        self._relayout_files_grid()
    
    def _on_splitter_moved(self, pos: int, index: int):
        """Handle splitter drag - relayout grids."""
        self._relayout_all()
    
    def resizeEvent(self, event):
        """Handle resize with debouncing."""
        super().resizeEvent(event)
        
        # Debounce resize events for both grids
        if self._resize_timer is None:
            self._resize_timer = QTimer()
            self._resize_timer.setSingleShot(True)
            self._resize_timer.timeout.connect(self._relayout_all)
        
        self._resize_timer.start(RESIZE_DEBOUNCE_MS)
    
    def keyPressEvent(self, event: QKeyEvent):
        """Handle keyboard shortcuts."""
        key = event.key()
        modifiers = event.modifiers()
        
        # Delete key - delete selected files
        if key == Qt.Key.Key_Delete or key == Qt.Key.Key_Backspace:
            if self.selected_files:
                self._delete_selected_files()
                return
        
        # Cmd/Ctrl + A - select all
        if key == Qt.Key.Key_A and modifiers & Qt.KeyboardModifier.ControlModifier:
            self._select_all()
            return
        
        # Escape - clear selection
        if key == Qt.Key.Key_Escape:
            self._clear_selection()
            return
        
        super().keyPressEvent(event)
    
    def _select_all(self):
        """Select all files in current view."""
        for thumb in self.thumbnail_widgets:
            thumb.selected = True
            self.selected_files.add(thumb.file_path)
        self._update_title()
    
    def apply_theme(self, is_dark: bool):
        """Apply theme to this page."""
        self._is_dark = is_dark
        
        if is_dark:
            # Apply dark styles
            self.back_btn.setStyleSheet(DARK_BACK_BUTTON_STYLE)
            self.open_folder_btn.setStyleSheet(DARK_BACK_BUTTON_STYLE)
            self.path_label.setStyleSheet(DARK_PATH_LABEL_STYLE)
            self.folders_frame.setStyleSheet(DARK_FOLDERS_FRAME_STYLE)
            self.files_frame.setStyleSheet(DARK_FILES_FRAME_STYLE)
            self.folders_scroll.setStyleSheet(DARK_SCROLL_AREA_STYLE)
            self.files_scroll.setStyleSheet(DARK_SCROLL_AREA_STYLE)
            self.splitter.setStyleSheet(DARK_SPLITTER_STYLE)
            self.size_slider.setStyleSheet(DARK_SIZE_SLIDER_STYLE)
            self.folders_title_label.setStyleSheet(DARK_HEADER_LABEL_STYLE)
            self.files_title.setStyleSheet(DARK_HEADER_LABEL_STYLE)
        else:
            # Apply light styles
            self.back_btn.setStyleSheet(BACK_BUTTON_STYLE)
            self.open_folder_btn.setStyleSheet(BACK_BUTTON_STYLE)
            self.path_label.setStyleSheet(PATH_LABEL_STYLE)
            self.folders_frame.setStyleSheet(FOLDERS_FRAME_STYLE)
            self.files_frame.setStyleSheet(FILES_FRAME_STYLE)
            self.folders_scroll.setStyleSheet(SCROLL_AREA_STYLE)
            self.files_scroll.setStyleSheet(SCROLL_AREA_STYLE)
            self.splitter.setStyleSheet(SPLITTER_STYLE)
            self.size_slider.setStyleSheet(SIZE_SLIDER_STYLE)
            self.folders_title_label.setStyleSheet(HEADER_LABEL_STYLE)
            self.files_title.setStyleSheet(HEADER_LABEL_STYLE)
        
        # Update folder buttons
        for btn in self.folder_buttons:
            btn.apply_theme(is_dark)
        
        # Update thumbnails
        for thumb in self.thumbnail_widgets:
            thumb.apply_theme(is_dark)
