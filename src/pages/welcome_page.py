"""
Welcome page with folder selection.
"""

import os
from pathlib import Path
from typing import Callable, List

from PyQt6.QtCore import Qt, QSize
from PyQt6.QtGui import QPixmap
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QFileDialog, QFrame,
    QMenu
)

try:
    import qtawesome as qta
    HAS_QTAWESOME = True
except ImportError:
    HAS_QTAWESOME = False


def get_icon_path() -> str:
    """Get the path to icon.png, works both in dev and packaged app."""
    # Try relative to this file first (development)
    base_dir = Path(__file__).parent.parent.parent
    icon_path = base_dir / "assets" / "icon.png"
    if icon_path.exists():
        return str(icon_path)
    
    # Try PyInstaller bundle path
    import sys
    if getattr(sys, 'frozen', False):
        bundle_dir = Path(sys._MEIPASS)
        icon_path = bundle_dir / "assets" / "icon.png"
        if icon_path.exists():
            return str(icon_path)
    
    return ""

from ..styles import SELECT_FOLDER_BUTTON_STYLE, CONTEXT_MENU_STYLE, DARK_CONTEXT_MENU_STYLE
from ..utils import get_recent_folders
from ..theme_manager import get_theme_manager


class WelcomePage(QWidget):
    """Welcome page with folder selection button."""
    
    def __init__(self, on_folder_selected: Callable[[str], None]):
        super().__init__()
        self.on_folder_selected = on_folder_selected
        self._is_dark = False
        self._theme_manager = get_theme_manager()
        self._init_ui()
    
    def _init_ui(self):
        """Initialize the UI components."""
        layout = QVBoxLayout()
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.setContentsMargins(40, 40, 40, 40)
        
        # Top bar with theme toggle
        top_bar = QHBoxLayout()
        top_bar.setContentsMargins(0, 0, 0, 0)
        
        top_bar.addStretch()
        
        # Theme toggle button
        self.theme_btn = QPushButton()
        self._update_theme_button()
        self.theme_btn.setFixedSize(40, 40)
        self.theme_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.theme_btn.clicked.connect(self._toggle_theme)
        self.theme_btn.setStyleSheet("""
            QPushButton {
                background-color: rgba(0, 0, 0, 0.05);
                border: none;
                border-radius: 20px;
                font-size: 18px;
            }
            QPushButton:hover {
                background-color: rgba(0, 0, 0, 0.1);
            }
        """)
        top_bar.addWidget(self.theme_btn)
        
        layout.addLayout(top_bar)
        
        # Card container
        self.card = QFrame()
        self._card_light_style = """
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #FFFFFF, stop:1 #F8FAFC);
                border: 1px solid #E2E8F0;
                border-radius: 24px;
            }
            QLabel {
                border: none;
                background: transparent;
            }
        """
        self._card_dark_style = """
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #2d2d44, stop:1 #252538);
                border: 1px solid #3d3d5c;
                border-radius: 24px;
            }
            QLabel {
                border: none;
                background: transparent;
            }
        """
        self.card.setStyleSheet(self._card_light_style)
        self.card.setFixedSize(480, 440)
        
        card_layout = QVBoxLayout(self.card)
        card_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        card_layout.setSpacing(12)
        card_layout.setContentsMargins(40, 40, 40, 40)
        
        # App icon - use custom icon.png
        logo_label = QLabel()
        logo_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon_path = get_icon_path()
        if icon_path:
            pixmap = QPixmap(icon_path)
            if not pixmap.isNull():
                # Scale to 72x72 with smooth transformation
                scaled = pixmap.scaled(
                    72, 72,
                    Qt.AspectRatioMode.KeepAspectRatio,
                    Qt.TransformationMode.SmoothTransformation
                )
                logo_label.setPixmap(scaled)
            else:
                logo_label.setText("📷")
                logo_label.setStyleSheet("font-size: 56px;")
        else:
            logo_label.setText("📷")
            logo_label.setStyleSheet("font-size: 56px;")
        
        # Title
        self.title = QLabel("图片整理")
        self.title.setStyleSheet("color: #1E293B; font-size: 28px; font-weight: bold;")
        self.title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # Subtitle
        self.subtitle = QLabel("Image Organizer")
        self.subtitle.setStyleSheet("color: #94A3B8; font-size: 13px; letter-spacing: 3px;")
        self.subtitle.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # Description
        self.desc = QLabel("轻松整理、分类和管理您的图片文件")
        self.desc.setStyleSheet("color: #64748B; font-size: 14px;")
        self.desc.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # Select button with icon
        self.select_btn = QPushButton("  选择文件夹")
        if HAS_QTAWESOME:
            self.select_btn.setIcon(qta.icon('fa5s.folder-open', color='white'))
            self.select_btn.setIconSize(QSize(16, 16))
        self.select_btn.setFixedSize(140, 44)
        self.select_btn.setStyleSheet(SELECT_FOLDER_BUTTON_STYLE)
        self.select_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.select_btn.clicked.connect(self._select_folder)
        
        # Recent folders button
        self.recent_btn = QPushButton("  最近打开")
        if HAS_QTAWESOME:
            self.recent_btn.setIcon(qta.icon('fa5s.history', color='#64748B'))
            self.recent_btn.setIconSize(QSize(16, 16))
        self.recent_btn.setFixedSize(140, 44)
        self.recent_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self._recent_btn_light_style = """
            QPushButton {
                background-color: #F1F5F9;
                color: #64748B;
                border: 1px solid #E2E8F0;
                border-radius: 10px;
                font-size: 13px;
            }
            QPushButton:hover {
                background-color: #E2E8F0;
                color: #475569;
            }
        """
        self._recent_btn_dark_style = """
            QPushButton {
                background-color: #3d3d5c;
                color: #a0a0b0;
                border: 1px solid #5d5d7c;
                border-radius: 10px;
                font-size: 13px;
            }
            QPushButton:hover {
                background-color: #4d4d6c;
                color: #e0e0e0;
            }
        """
        self.recent_btn.setStyleSheet(self._recent_btn_light_style)
        self.recent_btn.clicked.connect(self._show_recent_folders)
        
        # Buttons row
        buttons_row = QHBoxLayout()
        buttons_row.setSpacing(12)
        buttons_row.addWidget(self.select_btn)
        buttons_row.addWidget(self.recent_btn)
        
        # Features hint
        self.features = QLabel("拖拽排序  ·  批量重命名  ·  快速分类")
        self.features.setStyleSheet("color: #94A3B8; font-size: 11px;")
        self.features.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        card_layout.addWidget(logo_label)
        card_layout.addSpacing(8)
        card_layout.addWidget(self.title)
        card_layout.addWidget(self.subtitle)
        card_layout.addSpacing(16)
        card_layout.addWidget(self.desc)
        card_layout.addSpacing(24)
        card_layout.addLayout(buttons_row)
        card_layout.addSpacing(16)
        card_layout.addWidget(self.features)
        
        layout.addStretch()
        layout.addWidget(self.card, alignment=Qt.AlignmentFlag.AlignCenter)
        layout.addStretch()
        
        # Version info
        self.version = QLabel("v1.0.0")
        self.version.setStyleSheet("color: #CBD5E1; font-size: 11px; border: none;")
        self.version.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.version)
        
        self.setLayout(layout)
    
    def _update_theme_button(self):
        """Update theme button icon based on current mode."""
        if self._theme_manager.is_dark_mode:
            if HAS_QTAWESOME:
                self.theme_btn.setIcon(qta.icon('fa5s.sun', color='#FFD93D'))
                self.theme_btn.setIconSize(QSize(20, 20))
            else:
                self.theme_btn.setText("☀️")
            self.theme_btn.setToolTip("切换到浅色模式")
        else:
            if HAS_QTAWESOME:
                self.theme_btn.setIcon(qta.icon('fa5s.moon', color='#64748B'))
                self.theme_btn.setIconSize(QSize(20, 20))
            else:
                self.theme_btn.setText("🌙")
            self.theme_btn.setToolTip("切换到深色模式")
    
    def _toggle_theme(self):
        """Toggle between light and dark mode."""
        self._theme_manager.toggle_dark_mode()
        self._update_theme_button()
    
    def apply_theme(self, is_dark: bool):
        """Apply theme to this page."""
        self._is_dark = is_dark
        
        # Update card style
        if is_dark:
            self.card.setStyleSheet(self._card_dark_style)
            self.title.setStyleSheet("color: #e0e0e0; font-size: 28px; font-weight: bold;")
            self.subtitle.setStyleSheet("color: #7d7d9c; font-size: 13px; letter-spacing: 3px;")
            self.desc.setStyleSheet("color: #a0a0b0; font-size: 14px;")
            self.features.setStyleSheet("color: #7d7d9c; font-size: 11px;")
            self.version.setStyleSheet("color: #5d5d7c; font-size: 11px; border: none;")
            self.recent_btn.setStyleSheet(self._recent_btn_dark_style)
            self.theme_btn.setStyleSheet("""
                QPushButton {
                    background-color: rgba(255, 255, 255, 0.1);
                    border: none;
                    border-radius: 20px;
                    font-size: 18px;
                }
                QPushButton:hover {
                    background-color: rgba(255, 255, 255, 0.2);
                }
            """)
        else:
            self.card.setStyleSheet(self._card_light_style)
            self.title.setStyleSheet("color: #1E293B; font-size: 28px; font-weight: bold;")
            self.subtitle.setStyleSheet("color: #94A3B8; font-size: 13px; letter-spacing: 3px;")
            self.desc.setStyleSheet("color: #64748B; font-size: 14px;")
            self.features.setStyleSheet("color: #94A3B8; font-size: 11px;")
            self.version.setStyleSheet("color: #CBD5E1; font-size: 11px; border: none;")
            self.recent_btn.setStyleSheet(self._recent_btn_light_style)
            self.theme_btn.setStyleSheet("""
                QPushButton {
                    background-color: rgba(0, 0, 0, 0.05);
                    border: none;
                    border-radius: 20px;
                    font-size: 18px;
                }
                QPushButton:hover {
                    background-color: rgba(0, 0, 0, 0.1);
                }
            """)
        
        self._update_theme_button()
    
    def _select_folder(self):
        """Open folder selection dialog."""
        folder = QFileDialog.getExistingDirectory(
            self, 
            "选择文件夹", 
            str(Path.home()),
            QFileDialog.Option.ShowDirsOnly
        )
        if folder:
            self.on_folder_selected(folder)
    
    def _show_recent_folders(self):
        """Show menu with recent folders."""
        recent = get_recent_folders()
        
        if not recent:
            return
        
        menu = QMenu(self)
        menu.setStyleSheet(DARK_CONTEXT_MENU_STYLE if self._is_dark else CONTEXT_MENU_STYLE)
        
        for folder_path in recent:
            folder_name = os.path.basename(folder_path)
            if HAS_QTAWESOME:
                action = menu.addAction(
                    qta.icon('fa5s.folder', color='#5B7FFF'),
                    folder_name
                )
            else:
                action = menu.addAction(f"📁 {folder_name}")
            action.setData(folder_path)
            action.setToolTip(folder_path)
        
        # Show menu below the button
        pos = self.recent_btn.mapToGlobal(self.recent_btn.rect().bottomLeft())
        action = menu.exec(pos)
        
        if action and action.data():
            self.on_folder_selected(action.data())
