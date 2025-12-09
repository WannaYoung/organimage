"""
Thumbnail widget for displaying image previews with async loading.
"""

import os
from typing import Optional

from PyQt6.QtCore import Qt, QMimeData, QPoint, pyqtSignal, QTimer
from PyQt6.QtGui import QPixmap, QDrag
from PyQt6.QtWidgets import QFrame, QVBoxLayout, QLabel, QMenu

try:
    import qtawesome as qta
    HAS_QTAWESOME = True
except ImportError:
    HAS_QTAWESOME = False

from ..styles import (
    THUMBNAIL_STYLE, THUMBNAIL_SELECTED_STYLE, CONTEXT_MENU_STYLE, HOVER_LABEL_STYLE,
    DARK_THUMBNAIL_STYLE, DARK_THUMBNAIL_SELECTED_STYLE, DARK_CONTEXT_MENU_STYLE, DARK_HOVER_LABEL_STYLE
)
from ..thumbnail_cache import (
    get_cached_thumbnail, put_cached_thumbnail, make_cache_key,
    ThumbnailLoader, start_thumbnail_loader
)


class ThumbnailWidget(QFrame):
    """Widget displaying a file thumbnail with drag support and async loading."""
    
    clicked = pyqtSignal(str)
    ctrl_clicked = pyqtSignal(str)  # For multi-select with Ctrl/Cmd
    shift_clicked = pyqtSignal(str)  # For range select with Shift
    drag_started = pyqtSignal(str)  # Notify when drag starts
    reorder_requested = pyqtSignal(str, str)  # dragged_file, target_file (insert before)
    open_source_requested = pyqtSignal(str)
    delete_requested = pyqtSignal(str)
    rename_requested = pyqtSignal(str)
    double_clicked = pyqtSignal(str)  # For image preview
    
    def __init__(self, file_path: str, thumb_size: int = 120, current_dir: str = None):
        super().__init__()
        self.file_path = file_path
        self.thumb_size = thumb_size
        self.current_dir = current_dir
        self.drag_start_position = None
        self._loader: Optional[ThumbnailLoader] = None
        self._pixmap: Optional[QPixmap] = None
        self._selected = False
        self._get_selected_files = None  # Callback to get selected files from parent
        self._hover_label: Optional[QLabel] = None  # Custom tooltip
        self._tooltip_text = ""
        self._is_drag_over = False  # Track drag over state
        self._image_info = None  # Cached image info
        self._info_loaded = False  # Whether info has been loaded
        self._is_dark = False  # Dark mode state
        self.setAcceptDrops(True)  # Accept drops for reordering
        self._setup_ui()
        self._load_thumbnail_async()
    
    def set_selection_provider(self, callback):
        """Set callback to get selected files for multi-file drag."""
        self._get_selected_files = callback
    
    def _setup_ui(self):
        """Initialize the UI components."""
        self.setFixedSize(self.thumb_size + 4, self.thumb_size + 22)
        self.setCursor(Qt.CursorShape.OpenHandCursor)
        self.setStyleSheet(THUMBNAIL_STYLE)
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(2, 2, 2, 0)
        layout.setSpacing(0)
        
        # Image label
        self.image_label = QLabel()
        self.image_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.image_label.setFixedSize(self.thumb_size, self.thumb_size - 10)
        self.image_label.setStyleSheet("background: #F1F5F9; border: none; border-radius: 8px;")
        self.image_label.setText("⏳")  # Loading indicator
        
        # Filename label - styled
        self.name_label = QLabel()
        self.name_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.name_label.setStyleSheet(
            "font-size: 10px; color: #1E293B; background: transparent; border: none; font-weight: 500;"
        )
        self.name_label.setWordWrap(True)
        self.name_label.setFixedHeight(20)
        self.name_label.setContentsMargins(0, 0, 0, 0)
        
        layout.addWidget(self.image_label)
        layout.addWidget(self.name_label)
        
        # Set filename immediately
        file_name = os.path.basename(self.file_path)
        self._tooltip_text = file_name
        display_name = file_name if len(file_name) <= 12 else file_name[:10] + "..."
        self.name_label.setText(display_name)
    
    def enterEvent(self, event):
        """Show custom tooltip on hover."""
        super().enterEvent(event)
        self._show_hover_label()
    
    def leaveEvent(self, event):
        """Hide custom tooltip on leave."""
        super().leaveEvent(event)
        self._hide_hover_label()
    
    def hideEvent(self, event):
        """Ensure hover label is hidden when widget is hidden."""
        super().hideEvent(event)
        self._hide_hover_label()
    
    def _show_hover_label(self):
        """Show custom hover label with image info."""
        if self._hover_label is None:
            self._hover_label = QLabel()
            self._hover_label.setWindowFlags(
                Qt.WindowType.ToolTip | Qt.WindowType.FramelessWindowHint
            )
            self._hover_label.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, False)
            self._hover_label.setStyleSheet(DARK_HOVER_LABEL_STYLE if self._is_dark else HOVER_LABEL_STYLE)
        
        # Load image info on first hover
        if not self._info_loaded:
            self._load_image_info()
        
        # Build tooltip text with image info
        tooltip_lines = [self._tooltip_text]
        if self._image_info:
            if self._image_info.get('width') and self._image_info.get('height'):
                tooltip_lines.append(f"{self._image_info['width']} × {self._image_info['height']}")
            if self._image_info.get('size_str'):
                tooltip_lines.append(self._image_info['size_str'])
            if self._image_info.get('modified_str'):
                tooltip_lines.append(self._image_info['modified_str'])
        
        self._hover_label.setText('\n'.join(tooltip_lines))
        self._hover_label.adjustSize()
        
        # Position below the widget
        global_pos = self.mapToGlobal(QPoint(0, self.height() + 5))
        self._hover_label.move(global_pos)
        self._hover_label.show()
    
    def _load_image_info(self):
        """Load image info for tooltip display."""
        from ..utils import get_image_info
        self._image_info = get_image_info(self.file_path)
        self._info_loaded = True
    
    def _hide_hover_label(self):
        """Hide custom hover label."""
        if self._hover_label is not None:
            self._hover_label.hide()
            self._hover_label.deleteLater()
            self._hover_label = None
    
    def _load_thumbnail_async(self):
        """Load thumbnail asynchronously."""
        # Check cache first
        cache_key = make_cache_key(self.file_path, self.thumb_size - 10)
        cached = get_cached_thumbnail(cache_key)
        
        if cached and not cached.isNull():
            self._on_pixmap_ready(cached)
            return
        
        # Start async loader using thread pool
        self._cancel_loader()
        self._loader = ThumbnailLoader(self.file_path, self.thumb_size - 10)
        self._loader.image_ready.connect(self._on_image_ready)
        start_thumbnail_loader(self._loader)
    
    def _cancel_loader(self):
        """Cancel any running loader."""
        if self._loader is not None:
            try:
                self._loader.image_ready.disconnect()
            except (TypeError, RuntimeError):
                pass  # Already disconnected
            self._loader.cancel()
            # Thread pool manages lifecycle, just clear reference
            self._loader = None
    
    def _on_image_ready(self, file_path: str, image, size: int):
        """Handle loaded image from background thread - convert to QPixmap in main thread."""
        if file_path != self.file_path:
            return
        
        self._loader = None
        
        if not image.isNull():
            # Convert QImage to QPixmap in main thread (thread-safe)
            pixmap = QPixmap.fromImage(image)
            
            # Cache the result
            cache_key = make_cache_key(file_path, size)
            put_cached_thumbnail(cache_key, pixmap)
            
            self._on_pixmap_ready(pixmap)
        else:
            self.image_label.setText("📄")
            self.image_label.setStyleSheet(
                "font-size: 40px; background: transparent;"
            )
    
    def _on_pixmap_ready(self, pixmap: QPixmap):
        """Apply pixmap to the image label."""
        self._pixmap = pixmap
        if not pixmap.isNull():
            self.image_label.setStyleSheet("background: transparent;")
            self.image_label.setPixmap(pixmap)
        else:
            self.image_label.setText("📄")
            self.image_label.setStyleSheet(
                "font-size: 40px; background: transparent;"
            )
    
    @property
    def selected(self) -> bool:
        """Get selection state."""
        return self._selected
    
    @selected.setter
    def selected(self, value: bool):
        """Set selection state and update style."""
        if self._selected != value:
            self._selected = value
            self._update_style()
    
    def _update_style(self):
        """Update widget style based on selection and theme."""
        if self._is_dark:
            style = DARK_THUMBNAIL_SELECTED_STYLE if self._selected else DARK_THUMBNAIL_STYLE
        else:
            style = THUMBNAIL_SELECTED_STYLE if self._selected else THUMBNAIL_STYLE
        self.setStyleSheet(style)
    
    def apply_theme(self, is_dark: bool):
        """Apply theme to this widget."""
        self._is_dark = is_dark
        self._update_style()
        
        # Update name label color
        if is_dark:
            self.name_label.setStyleSheet(
                "font-size: 10px; color: #e0e0e0; background: transparent; border: none; font-weight: 500;"
            )
            # Update image label background for loading state
            if not self._pixmap or self._pixmap.isNull():
                self.image_label.setStyleSheet("background: #3d3d5c; border: none; border-radius: 8px;")
        else:
            self.name_label.setStyleSheet(
                "font-size: 10px; color: #1E293B; background: transparent; border: none; font-weight: 500;"
            )
            # Update image label background for loading state
            if not self._pixmap or self._pixmap.isNull():
                self.image_label.setStyleSheet("background: #F1F5F9; border: none; border-radius: 8px;")
        
        # Update hover label style if exists
        if self._hover_label:
            self._hover_label.setStyleSheet(DARK_HOVER_LABEL_STYLE if is_dark else HOVER_LABEL_STYLE)
    
    def update_size(self, new_size: int):
        """Update thumbnail size - only resize widget, use cached pixmap."""
        if new_size == self.thumb_size:
            return
        
        self.thumb_size = new_size
        self.setFixedSize(new_size + 4, new_size + 22)
        self.image_label.setFixedSize(new_size, new_size - 10)
        
        # If we have a cached pixmap, just rescale it (fast)
        if self._pixmap and not self._pixmap.isNull():
            scaled = self._pixmap.scaled(
                new_size - 10, new_size - 20,
                Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.FastTransformation  # Fast for resize
            )
            self.image_label.setPixmap(scaled)
        else:
            # Reload if no pixmap
            self._load_thumbnail_async()
    
    def cleanup(self):
        """Clean up resources - call before destroying widget."""
        # Cancel loader - thread pool handles lifecycle
        self._cancel_loader()
        
        # Clean up hover label to prevent memory leak
        if self._hover_label is not None:
            self._hover_label.hide()
            self._hover_label.deleteLater()
            self._hover_label = None
    
    def mousePressEvent(self, event):
        """Handle mouse press for selection and drag initiation."""
        if event.button() == Qt.MouseButton.LeftButton:
            self.drag_start_position = event.pos()
            # Handle selection with modifiers
            modifiers = event.modifiers()
            if modifiers & Qt.KeyboardModifier.ControlModifier:
                self.ctrl_clicked.emit(self.file_path)
            elif modifiers & Qt.KeyboardModifier.ShiftModifier:
                self.shift_clicked.emit(self.file_path)
            else:
                self.clicked.emit(self.file_path)
    
    def mouseDoubleClickEvent(self, event):
        """Handle double click for image preview."""
        if event.button() == Qt.MouseButton.LeftButton:
            self.double_clicked.emit(self.file_path)
    
    def mouseMoveEvent(self, event):
        """Handle mouse move for drag operation."""
        if not (event.buttons() & Qt.MouseButton.LeftButton):
            return
        if self.drag_start_position is None:
            return
        if (event.pos() - self.drag_start_position).manhattanLength() < 10:
            return
        
        # Get selected files from parent BEFORE emitting drag_started
        # This ensures we capture the current selection state
        selected_files = [self.file_path]
        if self._get_selected_files:
            selected = self._get_selected_files()
            if selected:
                if self.file_path in selected:
                    # Dragging a selected file - drag all selected
                    selected_files = list(selected)
                # else: dragging unselected file - just drag this one
        
        # Notify that drag is starting
        self.drag_started.emit(self.file_path)
        
        # Start drag operation with all selected files
        drag = QDrag(self)
        mime_data = QMimeData()
        # Use newline-separated paths for multi-file support
        mime_data.setText('\n'.join(selected_files))
        drag.setMimeData(mime_data)
        
        # Create drag pixmap with count badge if multiple files
        pixmap = self.grab()
        scaled_pixmap = pixmap.scaled(60, 60, Qt.AspectRatioMode.KeepAspectRatio)
        
        if len(selected_files) > 1:
            # Draw count badge
            from PyQt6.QtGui import QPainter, QColor, QFont as QGuiFont
            badge_pixmap = QPixmap(scaled_pixmap.size())
            badge_pixmap.fill(Qt.GlobalColor.transparent)
            painter = QPainter(badge_pixmap)
            painter.drawPixmap(0, 0, scaled_pixmap)
            
            # Draw badge circle
            painter.setBrush(QColor(33, 150, 243))  # Blue
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(scaled_pixmap.width() - 22, 0, 22, 22)
            
            # Draw count text
            painter.setPen(QColor(255, 255, 255))
            font = QGuiFont()
            font.setBold(True)
            font.setPointSize(10)
            painter.setFont(font)
            painter.drawText(scaled_pixmap.width() - 22, 0, 22, 22,
                           Qt.AlignmentFlag.AlignCenter, str(len(selected_files)))
            painter.end()
            drag.setPixmap(badge_pixmap)
        else:
            drag.setPixmap(scaled_pixmap)
        
        drag.setHotSpot(QPoint(30, 30))
        drag.exec(Qt.DropAction.MoveAction)
    
    def contextMenuEvent(self, event):
        """Right-click to show context menu."""
        menu = QMenu(self)
        menu.setStyleSheet(DARK_CONTEXT_MENU_STYLE if self._is_dark else CONTEXT_MENU_STYLE)
        
        if HAS_QTAWESOME:
            open_action = menu.addAction(qta.icon('fa5s.folder-open', color='#5B7FFF'), "打开来源")
        else:
            open_action = menu.addAction("打开来源")
        menu.addSeparator()
        if HAS_QTAWESOME:
            rename_action = menu.addAction(qta.icon('fa5s.edit', color='#64748B'), "重命名")
            delete_action = menu.addAction(qta.icon('fa5s.trash-alt', color='#EF4444'), "删除")
        else:
            rename_action = menu.addAction("重命名")
            delete_action = menu.addAction("删除")
        
        action = menu.exec(event.globalPos())
        
        if action == open_action:
            QTimer.singleShot(0, lambda: self.open_source_requested.emit(self.file_path))
        elif action == rename_action:
            QTimer.singleShot(0, lambda: self.rename_requested.emit(self.file_path))
        elif action == delete_action:
            QTimer.singleShot(0, lambda: self.delete_requested.emit(self.file_path))
    
    def dragEnterEvent(self, event):
        """Handle drag enter for reordering."""
        mime_data = event.mimeData()
        if mime_data.hasText():
            dragged_path = mime_data.text().split('\n')[0].strip()
            # Only accept if it's a different file from same directory
            if dragged_path != self.file_path and self.current_dir:
                if os.path.dirname(dragged_path) == self.current_dir:
                    self._is_drag_over = True
                    self._update_drag_style()
                    event.acceptProposedAction()
                    return
        event.ignore()
    
    def dragLeaveEvent(self, event):
        """Handle drag leave."""
        self._is_drag_over = False
        self._update_drag_style()
    
    def dropEvent(self, event):
        """Handle drop for reordering."""
        self._is_drag_over = False
        self._update_drag_style()
        
        mime_data = event.mimeData()
        if mime_data.hasText():
            dragged_path = mime_data.text().split('\n')[0].strip()
            if dragged_path != self.file_path:
                # Emit reorder signal: dragged file should be placed before this file
                self.reorder_requested.emit(dragged_path, self.file_path)
    
    def _update_drag_style(self):
        """Update style based on drag state."""
        if self._is_drag_over:
            self.setStyleSheet("""
                ThumbnailWidget {
                    background-color: #DBEAFE;
                    border: 3px dashed #5B7FFF;
                    border-radius: 12px;
                }
            """)
        else:
            self.setStyleSheet(THUMBNAIL_SELECTED_STYLE if self._selected else THUMBNAIL_STYLE)
