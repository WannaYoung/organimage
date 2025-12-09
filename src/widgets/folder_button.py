"""
Folder button widget for navigation and file drop.
Displays as a square with thumbnail preview.
"""

import os
from typing import Optional

from PyQt6.QtCore import Qt, pyqtSignal, QTimer, QPoint
from PyQt6.QtGui import QPixmap, QImageReader, QPainter, QColor, QFont
from PyQt6.QtWidgets import QFrame, QVBoxLayout, QLabel, QMenu, QApplication

try:
    import qtawesome as qta
    HAS_QTAWESOME = True
except ImportError:
    HAS_QTAWESOME = False

from ..constants import FOLDER_BUTTON_SIZE
from ..styles import CONTEXT_MENU_STYLE, HOVER_LABEL_STYLE, DARK_CONTEXT_MENU_STYLE, DARK_HOVER_LABEL_STYLE
from ..utils import count_files_in_directory, get_image_files


class FolderButton(QFrame):
    """Square folder button with thumbnail background."""
    
    folder_clicked = pyqtSignal(str)
    folder_selected = pyqtSignal(str)  # For selection state
    rename_requested = pyqtSignal(str)
    delete_requested = pyqtSignal(str)
    open_source_requested = pyqtSignal(str)
    files_dropped = pyqtSignal(list, str)  # file_paths (list), folder_path
    
    def __init__(self, folder_path: str, is_root: bool = False):
        super().__init__()
        self.folder_path = folder_path
        self.is_root = is_root
        self.folder_name = os.path.basename(folder_path) if not is_root else "根目录"
        self.setAcceptDrops(True)
        self._thumbnail: Optional[QPixmap] = None
        self._selected = False  # Track selection state
        self._hover_label: Optional[QLabel] = None  # Custom tooltip
        self._is_dark = False  # Dark mode state
        self._setup_ui()
        self._load_thumbnail()
    
    def _setup_ui(self):
        """Initialize the UI."""
        self.setFixedSize(FOLDER_BUTTON_SIZE, FOLDER_BUTTON_SIZE)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        
        # Name label at bottom with semi-transparent background
        self.name_label = QLabel()
        self.name_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.name_label.setFixedHeight(24)
        
        layout.addStretch()
        layout.addWidget(self.name_label)
        
        self._update_display()
    
    def _load_thumbnail(self):
        """Load first image as thumbnail background."""
        if self.is_root:
            return
        
        images = get_image_files(self.folder_path)
        if images:
            reader = QImageReader(images[0])
            reader.setAutoTransform(True)
            image = reader.read()
            if not image.isNull():
                pixmap = QPixmap.fromImage(image)
                # Target size for thumbnail (accounting for border)
                target_size = FOLDER_BUTTON_SIZE - 6
                
                # Scale to cover the target size
                scaled = pixmap.scaled(
                    target_size, target_size,
                    Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                    Qt.TransformationMode.SmoothTransformation
                )
                
                # Center crop to exact square
                x = (scaled.width() - target_size) // 2
                y = (scaled.height() - target_size) // 2
                self._thumbnail = scaled.copy(x, y, target_size, target_size)
        
        self._update_display()
    
    def _update_display(self):
        """Update button display."""
        file_count = count_files_in_directory(self.folder_path)
        
        # Update name label - allow more characters
        display_name = self.folder_name if len(self.folder_name) <= 8 else self.folder_name[:7] + "…"
        self.name_label.setText(f"{display_name}({file_count})")
        self._tooltip_text = f"{self.folder_name} ({file_count} 个文件)"
        
        # Set style based on state
        self._apply_style(False)
    
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
        """Show custom hover label."""
        if self._hover_label is None:
            self._hover_label = QLabel()
            self._hover_label.setWindowFlags(
                Qt.WindowType.ToolTip | Qt.WindowType.FramelessWindowHint
            )
            self._hover_label.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, False)
            self._hover_label.setStyleSheet(HOVER_LABEL_STYLE if not self._is_dark else DARK_HOVER_LABEL_STYLE)
        
        self._hover_label.setText(self._tooltip_text)
        self._hover_label.adjustSize()
        
        # Position below the widget
        global_pos = self.mapToGlobal(QPoint(0, self.height() + 5))
        self._hover_label.move(global_pos)
        self._hover_label.show()
    
    def _hide_hover_label(self):
        """Hide custom hover label."""
        if self._hover_label is not None:
            self._hover_label.hide()
            self._hover_label.deleteLater()
            self._hover_label = None
    
    @property
    def selected(self) -> bool:
        """Get selection state."""
        return self._selected
    
    @selected.setter
    def selected(self, value: bool):
        """Set selection state and update style."""
        if self._selected != value:
            self._selected = value
            self._apply_style(False)
    
    def _apply_style(self, is_drag_over: bool):
        """Apply visual style with background image."""
        # Root folder - special gradient style
        if self.is_root:
            if is_drag_over:
                self.setStyleSheet("""
                    FolderButton {
                        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                            stop:0 #5B7FFF, stop:1 #7C3AED);
                        border: 3px dashed #10B981;
                        border-radius: 14px;
                    }
                """)
            elif self._selected:
                self.setStyleSheet("""
                    FolderButton {
                        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                            stop:0 #7C3AED, stop:1 #5B7FFF);
                        border: 3px solid white;
                        border-radius: 14px;
                    }
                """)
            else:
                self.setStyleSheet("""
                    FolderButton {
                        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                            stop:0 #5B7FFF, stop:1 #7C3AED);
                        border: none;
                        border-radius: 14px;
                    }
                    FolderButton:hover {
                        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                            stop:0 #7C3AED, stop:1 #5B7FFF);
                    }
                """)
            self.name_label.setStyleSheet("""
                background: rgba(0, 0, 0, 0.3);
                color: white;
                font-size: 10px;
                font-weight: 600;
                padding: 2px 4px;
                border: none;
                border-bottom-left-radius: 14px;
                border-bottom-right-radius: 14px;
            """)
            return
        
        # Selected or drag over state - blue/green border
        if is_drag_over or self._selected:
            border_style = "3px dashed #10B981" if is_drag_over else "3px solid #5B7FFF"
            bg_color = "#D1FAE5" if is_drag_over else "#EEF2FF"
            label_bg = "rgba(16, 185, 129, 0.9)" if is_drag_over else "rgba(91, 127, 255, 0.9)"
            self.setStyleSheet(f"""
                FolderButton {{
                    background-color: {bg_color};
                    border: {border_style};
                    border-radius: 14px;
                }}
                FolderButton:hover {{
                    background-color: {bg_color};
                    border: {border_style};
                }}
            """)
            self.name_label.setStyleSheet(f"""
                background: {label_bg};
                color: white;
                font-size: 10px;
                font-weight: 600;
                padding: 2px 4px;
                border: none;
                border-bottom-left-radius: 14px;
                border-bottom-right-radius: 14px;
            """)
        elif self._thumbnail and not self._thumbnail.isNull():
            # Has thumbnail - use image as background
            border_color = "#3d3d5c" if self._is_dark else "#E2E8F0"
            self.setStyleSheet(f"""
                FolderButton {{
                    border: 2px solid {border_color};
                    border-radius: 14px;
                }}
                FolderButton:hover {{
                    border: 3px solid #10B981;
                }}
            """)
            if self._is_dark:
                self.name_label.setStyleSheet("""
                    background: rgba(45, 45, 68, 0.95);
                    color: #e0e0e0;
                    font-size: 10px;
                    font-weight: 600;
                    padding: 2px 4px;
                    border: none;
                    border-bottom-left-radius: 14px;
                    border-bottom-right-radius: 14px;
                """)
            else:
                self.name_label.setStyleSheet("""
                    background: rgba(255, 255, 255, 0.95);
                    color: #1E293B;
                    font-size: 10px;
                    font-weight: 600;
                    padding: 2px 4px;
                    border: none;
                    border-bottom-left-radius: 14px;
                    border-bottom-right-radius: 14px;
                """)
        else:
            # No thumbnail - show folder icon style
            if self._is_dark:
                self.setStyleSheet("""
                    FolderButton {
                        background-color: #2d2d44;
                        border: 2px solid #3d3d5c;
                        border-radius: 14px;
                    }
                    FolderButton:hover {
                        border: 3px solid #10B981;
                        background-color: #3d3d5c;
                    }
                """)
                self.name_label.setStyleSheet("""
                    background: rgba(45, 45, 68, 0.95);
                    color: #e0e0e0;
                    font-size: 10px;
                    font-weight: 600;
                    padding: 2px 4px;
                    border: none;
                    border-bottom-left-radius: 14px;
                    border-bottom-right-radius: 14px;
                """)
            else:
                self.setStyleSheet("""
                    FolderButton {
                        background-color: #F8FAFC;
                        border: 2px solid #E2E8F0;
                        border-radius: 14px;
                    }
                    FolderButton:hover {
                        border: 3px solid #10B981;
                        background-color: #F0FDF4;
                    }
                """)
                self.name_label.setStyleSheet("""
                    background: rgba(255, 255, 255, 0.95);
                    color: #1E293B;
                    font-size: 10px;
                    font-weight: 600;
                    padding: 2px 4px;
                    border: none;
                    border-bottom-left-radius: 14px;
                    border-bottom-right-radius: 14px;
                """)
    
    def paintEvent(self, event):
        """Custom paint to draw thumbnail background."""
        super().paintEvent(event)
        
        if self._thumbnail and not self._thumbnail.isNull() and not self.is_root:
            painter = QPainter(self)
            painter.setRenderHint(QPainter.RenderHint.Antialiasing)
            
            # Draw rounded rect with thumbnail
            from PyQt6.QtGui import QPainterPath, QBrush
            path = QPainterPath()
            path.addRoundedRect(3, 3, FOLDER_BUTTON_SIZE - 6, FOLDER_BUTTON_SIZE - 6, 7, 7)
            painter.setClipPath(path)
            painter.drawPixmap(3, 3, self._thumbnail)
            painter.end()
        elif not self._thumbnail and not self.is_root:
            # Draw folder icon in center
            painter = QPainter(self)
            painter.setRenderHint(QPainter.RenderHint.TextAntialiasing)
            font = QFont()
            font.setPointSize(32)
            painter.setFont(font)
            if HAS_QTAWESOME:
                icon = qta.icon('fa5s.folder', color='#94A3B8')
                icon_size = 36
                x = (self.width() - icon_size) // 2
                y = (self.height() - icon_size) // 2 - 8
                icon.paint(painter, x, y, icon_size, icon_size)
            else:
                painter.setPen(QColor("#888888"))
                painter.drawText(self.rect().adjusted(0, -10, 0, -10), Qt.AlignmentFlag.AlignCenter, "📁")
            painter.end()
        elif self.is_root:
            # Draw home icon
            painter = QPainter(self)
            painter.setRenderHint(QPainter.RenderHint.Antialiasing)
            if HAS_QTAWESOME:
                icon = qta.icon('fa5s.home', color='white')
                icon_size = 36
                x = (self.width() - icon_size) // 2
                y = (self.height() - icon_size) // 2 - 8
                icon.paint(painter, x, y, icon_size, icon_size)
            else:
                font = QFont()
                font.setPointSize(32)
                painter.setFont(font)
                painter.setPen(QColor("white"))
                painter.drawText(self.rect().adjusted(0, -10, 0, -10), Qt.AlignmentFlag.AlignCenter, "🏠")
            painter.end()
    
    def update_count(self):
        """Update file count and reload thumbnail."""
        self._load_thumbnail()
    
    def cleanup(self):
        """Clean up resources to prevent memory leak."""
        if self._hover_label is not None:
            self._hover_label.hide()
            self._hover_label.deleteLater()
            self._hover_label = None
    
    def mousePressEvent(self, event):
        """Handle click - select folder and navigate."""
        if event.button() == Qt.MouseButton.LeftButton:
            # Select this folder and navigate to it
            self.folder_selected.emit(self.folder_path)
            self.folder_clicked.emit(self.folder_path)
    
    def contextMenuEvent(self, event):
        """Right-click to show context menu."""
        menu = QMenu(self)
        menu.setStyleSheet(DARK_CONTEXT_MENU_STYLE if self._is_dark else CONTEXT_MENU_STYLE)
        
        # Open in Finder action - available for all folders
        if HAS_QTAWESOME:
            open_action = menu.addAction(qta.icon('fa5s.folder-open', color='#5B7FFF'), "打开来源")
        else:
            open_action = menu.addAction("打开来源")
        
        # Separator and other actions only for non-root folders
        if not self.is_root:
            menu.addSeparator()
            if HAS_QTAWESOME:
                rename_action = menu.addAction(qta.icon('fa5s.edit', color='#64748B'), "重命名")
                delete_action = menu.addAction(qta.icon('fa5s.trash-alt', color='#EF4444'), "删除")
            else:
                rename_action = menu.addAction("重命名")
                delete_action = menu.addAction("删除")
        else:
            rename_action = None
            delete_action = None
        
        action = menu.exec(event.globalPos())
        
        if action == open_action:
            QTimer.singleShot(0, lambda: self.open_source_requested.emit(self.folder_path))
        elif action == rename_action:
            QTimer.singleShot(0, lambda: self.rename_requested.emit(self.folder_path))
        elif action == delete_action:
            QTimer.singleShot(0, lambda: self.delete_requested.emit(self.folder_path))
    
    def dragEnterEvent(self, event):
        """Handle drag enter event."""
        if event.mimeData().hasText() and not self.is_root:
            self._apply_style(True)
            event.acceptProposedAction()
    
    def dragLeaveEvent(self, event):
        """Handle drag leave event."""
        self._apply_style(False)
    
    def dropEvent(self, event):
        """Handle file drop event - supports multiple files."""
        if self.is_root:
            return
        
        mime_data = event.mimeData()
        
        # Check for multiple files (newline separated)
        text = mime_data.text()
        if text:
            file_paths = [p.strip() for p in text.split('\n') if p.strip() and os.path.exists(p.strip())]
            if file_paths:
                self.files_dropped.emit(file_paths, self.folder_path)
        
        self._apply_style(False)
    
    def apply_theme(self, is_dark: bool):
        """Apply theme to this widget."""
        self._is_dark = is_dark
        self._apply_style(False)
        
        # Update hover label style if exists
        if self._hover_label:
            self._hover_label.setStyleSheet(DARK_HOVER_LABEL_STYLE if is_dark else HOVER_LABEL_STYLE)
