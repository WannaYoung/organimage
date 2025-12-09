"""
Welcome page with folder selection.
"""

import os
from pathlib import Path
from typing import Callable

from PyQt6.QtCore import Qt, QSize
from PyQt6.QtGui import QPixmap
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QFileDialog, QFrame
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

from ..styles import SELECT_FOLDER_BUTTON_STYLE


class WelcomePage(QWidget):
    """Welcome page with folder selection button."""
    
    def __init__(self, on_folder_selected: Callable[[str], None]):
        super().__init__()
        self.on_folder_selected = on_folder_selected
        self._init_ui()
    
    def _init_ui(self):
        """Initialize the UI components."""
        layout = QVBoxLayout()
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.setContentsMargins(40, 40, 40, 40)
        
        # Card container
        card = QFrame()
        card.setStyleSheet("""
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
        """)
        card.setFixedSize(480, 400)
        
        card_layout = QVBoxLayout(card)
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
        title = QLabel("图片整理")
        title.setStyleSheet("color: #1E293B; font-size: 28px; font-weight: bold;")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # Subtitle
        subtitle = QLabel("Image Organizer")
        subtitle.setStyleSheet("color: #94A3B8; font-size: 13px; letter-spacing: 3px;")
        subtitle.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # Description
        desc = QLabel("轻松整理、分类和管理您的图片文件")
        desc.setStyleSheet("color: #64748B; font-size: 14px;")
        desc.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # Select button with icon
        self.select_btn = QPushButton("  选择文件夹开始")
        if HAS_QTAWESOME:
            self.select_btn.setIcon(qta.icon('fa5s.folder-open', color='white'))
            self.select_btn.setIconSize(QSize(18, 18))
        self.select_btn.setFixedSize(220, 48)
        self.select_btn.setStyleSheet(SELECT_FOLDER_BUTTON_STYLE)
        self.select_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.select_btn.clicked.connect(self._select_folder)
        
        # Features hint
        features = QLabel("拖拽排序  ·  批量重命名  ·  快速分类")
        features.setStyleSheet("color: #94A3B8; font-size: 11px;")
        features.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        card_layout.addWidget(logo_label)
        card_layout.addSpacing(8)
        card_layout.addWidget(title)
        card_layout.addWidget(subtitle)
        card_layout.addSpacing(16)
        card_layout.addWidget(desc)
        card_layout.addSpacing(24)
        card_layout.addWidget(self.select_btn, alignment=Qt.AlignmentFlag.AlignCenter)
        card_layout.addSpacing(16)
        card_layout.addWidget(features)
        
        layout.addStretch()
        layout.addWidget(card, alignment=Qt.AlignmentFlag.AlignCenter)
        layout.addStretch()
        
        # Version info
        version = QLabel("v1.0.0")
        version.setStyleSheet("color: #CBD5E1; font-size: 11px; border: none;")
        version.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(version)
        
        self.setLayout(layout)
    
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
