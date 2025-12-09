"""
Image preview dialog with fullscreen view, navigation, and zoom.
"""

import os
from typing import List, Optional

from PyQt6.QtCore import Qt, QPoint, QSize, QTimer
from PyQt6.QtGui import QPixmap, QKeyEvent, QWheelEvent, QMouseEvent, QPainter, QColor
from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QWidget,
    QScrollArea, QApplication, QFrame
)

try:
    import qtawesome as qta
    HAS_QTAWESOME = True
except ImportError:
    HAS_QTAWESOME = False


class ImagePreviewDialog(QDialog):
    """Fullscreen image preview dialog with navigation and zoom."""
    
    def __init__(self, file_path: str, file_list: List[str], parent=None):
        super().__init__(parent)
        self.file_list = file_list if file_list else [file_path]
        self.current_index = self.file_list.index(file_path) if file_path in self.file_list else 0
        self.zoom_level = 1.0
        self.min_zoom = 0.1
        self.max_zoom = 5.0
        self.drag_start = None
        self.scroll_start_h = 0
        self.scroll_start_v = 0
        self._original_pixmap: Optional[QPixmap] = None
        
        self._setup_ui()
        self._load_image()
        self._setup_shortcuts()
    
    def _setup_ui(self):
        """Initialize the UI components."""
        self.setWindowTitle("图片预览")
        self.setModal(True)
        self.setMinimumSize(800, 600)
        
        # Dark background style
        self.setStyleSheet("""
            QDialog {
                background-color: #1a1a1a;
            }
            QLabel {
                color: #ffffff;
                background: transparent;
            }
            QPushButton {
                background-color: rgba(255, 255, 255, 0.1);
                color: white;
                border: none;
                border-radius: 8px;
                padding: 12px;
                font-size: 16px;
            }
            QPushButton:hover {
                background-color: rgba(255, 255, 255, 0.2);
            }
            QPushButton:pressed {
                background-color: rgba(255, 255, 255, 0.3);
            }
            QScrollArea {
                border: none;
                background: transparent;
            }
            QScrollBar:vertical, QScrollBar:horizontal {
                background: rgba(255, 255, 255, 0.1);
                width: 8px;
                height: 8px;
                border-radius: 4px;
            }
            QScrollBar::handle:vertical, QScrollBar::handle:horizontal {
                background: rgba(255, 255, 255, 0.3);
                border-radius: 4px;
                min-height: 30px;
                min-width: 30px;
            }
            QScrollBar::handle:vertical:hover, QScrollBar::handle:horizontal:hover {
                background: rgba(255, 255, 255, 0.5);
            }
            QScrollBar::add-line, QScrollBar::sub-line {
                height: 0px;
                width: 0px;
            }
        """)
        
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        
        # Top bar with info and close button
        top_bar = QFrame()
        top_bar.setFixedHeight(50)
        top_bar.setStyleSheet("background-color: rgba(0, 0, 0, 0.5);")
        top_layout = QHBoxLayout(top_bar)
        top_layout.setContentsMargins(16, 8, 16, 8)
        
        # File info
        self.info_label = QLabel()
        self.info_label.setStyleSheet("font-size: 13px; color: #cccccc;")
        
        # Counter
        self.counter_label = QLabel()
        self.counter_label.setStyleSheet("font-size: 13px; color: #888888;")
        
        # Close button
        close_btn = QPushButton("✕")
        close_btn.setFixedSize(36, 36)
        close_btn.clicked.connect(self.close)
        
        top_layout.addWidget(self.info_label, 1)
        top_layout.addWidget(self.counter_label)
        top_layout.addWidget(close_btn)
        
        main_layout.addWidget(top_bar)
        
        # Image area with scroll
        self.scroll_area = QScrollArea()
        self.scroll_area.setWidgetResizable(True)
        self.scroll_area.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        self.image_container = QWidget()
        self.image_container.setStyleSheet("background: transparent;")
        container_layout = QVBoxLayout(self.image_container)
        container_layout.setContentsMargins(0, 0, 0, 0)
        container_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        self.image_label = QLabel()
        self.image_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.image_label.setStyleSheet("background: transparent;")
        container_layout.addWidget(self.image_label)
        
        self.scroll_area.setWidget(self.image_container)
        main_layout.addWidget(self.scroll_area, 1)
        
        # Navigation overlay - left
        self.prev_btn = QPushButton()
        if HAS_QTAWESOME:
            self.prev_btn.setIcon(qta.icon('fa5s.chevron-left', color='white'))
            self.prev_btn.setIconSize(QSize(24, 24))
        else:
            self.prev_btn.setText("◀")
        self.prev_btn.setFixedSize(50, 80)
        self.prev_btn.clicked.connect(self._prev_image)
        self.prev_btn.setParent(self)
        
        # Navigation overlay - right
        self.next_btn = QPushButton()
        if HAS_QTAWESOME:
            self.next_btn.setIcon(qta.icon('fa5s.chevron-right', color='white'))
            self.next_btn.setIconSize(QSize(24, 24))
        else:
            self.next_btn.setText("▶")
        self.next_btn.setFixedSize(50, 80)
        self.next_btn.clicked.connect(self._next_image)
        self.next_btn.setParent(self)
        
        # Bottom bar with zoom controls
        bottom_bar = QFrame()
        bottom_bar.setFixedHeight(50)
        bottom_bar.setStyleSheet("background-color: rgba(0, 0, 0, 0.5);")
        bottom_layout = QHBoxLayout(bottom_bar)
        bottom_layout.setContentsMargins(16, 8, 16, 8)
        
        # Zoom controls
        zoom_out_btn = QPushButton()
        if HAS_QTAWESOME:
            zoom_out_btn.setIcon(qta.icon('fa5s.search-minus', color='white'))
        else:
            zoom_out_btn.setText("−")
        zoom_out_btn.setFixedSize(36, 36)
        zoom_out_btn.clicked.connect(self._zoom_out)
        
        self.zoom_label = QLabel("100%")
        self.zoom_label.setFixedWidth(60)
        self.zoom_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.zoom_label.setStyleSheet("font-size: 13px;")
        
        zoom_in_btn = QPushButton()
        if HAS_QTAWESOME:
            zoom_in_btn.setIcon(qta.icon('fa5s.search-plus', color='white'))
        else:
            zoom_in_btn.setText("+")
        zoom_in_btn.setFixedSize(36, 36)
        zoom_in_btn.clicked.connect(self._zoom_in)
        
        fit_btn = QPushButton()
        if HAS_QTAWESOME:
            fit_btn.setIcon(qta.icon('fa5s.expand', color='white'))
        else:
            fit_btn.setText("⊡")
        fit_btn.setFixedSize(36, 36)
        fit_btn.setToolTip("适应窗口")
        fit_btn.clicked.connect(self._fit_to_window)
        
        actual_btn = QPushButton()
        if HAS_QTAWESOME:
            actual_btn.setIcon(qta.icon('fa5s.compress', color='white'))
        else:
            actual_btn.setText("1:1")
        actual_btn.setFixedSize(36, 36)
        actual_btn.setToolTip("实际大小")
        actual_btn.clicked.connect(self._actual_size)
        
        bottom_layout.addStretch()
        bottom_layout.addWidget(zoom_out_btn)
        bottom_layout.addWidget(self.zoom_label)
        bottom_layout.addWidget(zoom_in_btn)
        bottom_layout.addSpacing(16)
        bottom_layout.addWidget(fit_btn)
        bottom_layout.addWidget(actual_btn)
        bottom_layout.addStretch()
        
        main_layout.addWidget(bottom_bar)
        
        # Enable mouse tracking for drag
        self.image_label.setMouseTracking(True)
        self.scroll_area.viewport().installEventFilter(self)
    
    def _setup_shortcuts(self):
        """Setup keyboard shortcuts."""
        pass  # Handled in keyPressEvent
    
    def _load_image(self):
        """Load and display the current image."""
        if not self.file_list or self.current_index >= len(self.file_list):
            return
        
        file_path = self.file_list[self.current_index]
        
        # Load original pixmap
        self._original_pixmap = QPixmap(file_path)
        
        if self._original_pixmap.isNull():
            self.image_label.setText("无法加载图片")
            return
        
        # Update info
        file_name = os.path.basename(file_path)
        file_size = os.path.getsize(file_path)
        size_str = self._format_size(file_size)
        dimensions = f"{self._original_pixmap.width()} × {self._original_pixmap.height()}"
        
        self.info_label.setText(f"{file_name}  |  {dimensions}  |  {size_str}")
        self.counter_label.setText(f"{self.current_index + 1} / {len(self.file_list)}")
        
        # Fit to window on load
        self._fit_to_window()
        
        # Update navigation buttons
        self.prev_btn.setEnabled(self.current_index > 0)
        self.next_btn.setEnabled(self.current_index < len(self.file_list) - 1)
        self.prev_btn.setVisible(len(self.file_list) > 1)
        self.next_btn.setVisible(len(self.file_list) > 1)
    
    def _apply_zoom(self):
        """Apply current zoom level to the image."""
        if self._original_pixmap is None or self._original_pixmap.isNull():
            return
        
        new_size = self._original_pixmap.size() * self.zoom_level
        scaled = self._original_pixmap.scaled(
            new_size,
            Qt.AspectRatioMode.KeepAspectRatio,
            Qt.TransformationMode.SmoothTransformation
        )
        self.image_label.setPixmap(scaled)
        self.image_label.setFixedSize(scaled.size())
        self.zoom_label.setText(f"{int(self.zoom_level * 100)}%")
    
    def _fit_to_window(self):
        """Fit image to window size - scale down large images, keep small images at 100%."""
        if self._original_pixmap is None or self._original_pixmap.isNull():
            return
        
        viewport_size = self.scroll_area.viewport().size()
        img_size = self._original_pixmap.size()
        
        # Use window size if viewport not ready yet
        if viewport_size.width() < 100 or viewport_size.height() < 100:
            viewport_size = self.size()
        
        # Calculate available space (with padding)
        available_w = viewport_size.width() - 40
        available_h = viewport_size.height() - 100  # Extra space for toolbar
        
        # If image fits at 100%, use 100%
        if img_size.width() <= available_w and img_size.height() <= available_h:
            self.zoom_level = 1.0
        else:
            # Scale down to fit
            zoom_w = available_w / img_size.width()
            zoom_h = available_h / img_size.height()
            self.zoom_level = min(zoom_w, zoom_h)
        
        self._apply_zoom()
    
    def _actual_size(self):
        """Show image at actual size (100%)."""
        self.zoom_level = 1.0
        self._apply_zoom()
    
    def _zoom_in(self):
        """Zoom in by 25%."""
        self.zoom_level = min(self.zoom_level * 1.25, self.max_zoom)
        self._apply_zoom()
    
    def _zoom_out(self):
        """Zoom out by 25%."""
        self.zoom_level = max(self.zoom_level / 1.25, self.min_zoom)
        self._apply_zoom()
    
    def _prev_image(self):
        """Go to previous image."""
        if self.current_index > 0:
            self.current_index -= 1
            self._load_image()
    
    def _next_image(self):
        """Go to next image."""
        if self.current_index < len(self.file_list) - 1:
            self.current_index += 1
            self._load_image()
    
    def _format_size(self, size: int) -> str:
        """Format file size to human readable string."""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size < 1024:
                if unit == 'B':
                    return f"{int(size)} {unit}"
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} TB"
    
    def keyPressEvent(self, event: QKeyEvent):
        """Handle keyboard navigation."""
        key = event.key()
        
        if key == Qt.Key.Key_Escape:
            self.close()
        elif key == Qt.Key.Key_Left:
            self._prev_image()
        elif key == Qt.Key.Key_Right:
            self._next_image()
        elif key == Qt.Key.Key_Plus or key == Qt.Key.Key_Equal:
            self._zoom_in()
        elif key == Qt.Key.Key_Minus:
            self._zoom_out()
        elif key == Qt.Key.Key_0:
            self._actual_size()
        elif key == Qt.Key.Key_F:
            self._fit_to_window()
        else:
            super().keyPressEvent(event)
    
    def wheelEvent(self, event: QWheelEvent):
        """Handle mouse wheel for zoom."""
        if event.modifiers() & Qt.KeyboardModifier.ControlModifier:
            delta = event.angleDelta().y()
            if delta > 0:
                self._zoom_in()
            else:
                self._zoom_out()
            event.accept()
        else:
            super().wheelEvent(event)
    
    def resizeEvent(self, event):
        """Reposition navigation buttons on resize."""
        if event is not None:
            super().resizeEvent(event)
        
        # Position prev button on left
        self.prev_btn.move(20, (self.height() - self.prev_btn.height()) // 2)
        
        # Position next button on right
        self.next_btn.move(
            self.width() - self.next_btn.width() - 20,
            (self.height() - self.next_btn.height()) // 2
        )
    
    def showEvent(self, event):
        """Show dialog with appropriate size (80% of screen)."""
        super().showEvent(event)
        
        # Get screen size and set to 80%
        screen = QApplication.primaryScreen().geometry()
        width = int(screen.width() * 0.8)
        height = int(screen.height() * 0.8)
        self.resize(width, height)
        
        # Center on screen
        x = (screen.width() - width) // 2
        y = (screen.height() - height) // 2
        self.move(x, y)
        
        # Reposition buttons and refit image after window is shown
        QTimer.singleShot(100, self._on_show_complete)
    
    def _on_show_complete(self):
        """Called after window is fully shown."""
        self.resizeEvent(None)
        self._fit_to_window()
    
    def eventFilter(self, obj, event):
        """Handle mouse events for dragging."""
        if obj == self.scroll_area.viewport():
            if event.type() == event.Type.MouseButtonPress:
                if event.button() == Qt.MouseButton.LeftButton:
                    self.drag_start = event.pos()
                    self.scroll_start_h = self.scroll_area.horizontalScrollBar().value()
                    self.scroll_start_v = self.scroll_area.verticalScrollBar().value()
                    self.scroll_area.viewport().setCursor(Qt.CursorShape.ClosedHandCursor)
                    return True
            elif event.type() == event.Type.MouseButtonRelease:
                self.drag_start = None
                self.scroll_area.viewport().setCursor(Qt.CursorShape.OpenHandCursor)
                return True
            elif event.type() == event.Type.MouseMove:
                if self.drag_start is not None:
                    delta = event.pos() - self.drag_start
                    self.scroll_area.horizontalScrollBar().setValue(
                        self.scroll_start_h - delta.x()
                    )
                    self.scroll_area.verticalScrollBar().setValue(
                        self.scroll_start_v - delta.y()
                    )
                    return True
        return super().eventFilter(obj, event)
