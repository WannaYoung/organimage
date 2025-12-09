"""
Stylesheet definitions for UI components.
Professional design with modern aesthetics.
"""

# =============================================================================
# Color Palette - Professional Blue Theme
# =============================================================================
# Primary: #5B7FFF (Vibrant Blue)
# Secondary: #7C3AED (Purple accent)
# Success: #10B981 (Emerald Green)
# Background: #F8FAFC (Light Gray)
# Surface: #FFFFFF (White)
# Text Primary: #1E293B (Dark Slate)
# Text Secondary: #64748B (Slate Gray)
# Border: #E2E8F0 (Light Border)

# =============================================================================
# Main Window
# =============================================================================
MAIN_WINDOW_STYLE = """
    QMainWindow {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
            stop:0 #F8FAFC, stop:1 #EEF2FF);
    }
"""

# =============================================================================
# Button Styles
# =============================================================================
BACK_BUTTON_STYLE = """
    QPushButton {
        background-color: #FFFFFF;
        color: #475569;
        border: 1px solid #E2E8F0;
        border-radius: 8px;
        padding: 8px 16px;
        font-size: 13px;
        font-weight: 600;
    }
    QPushButton:hover { 
        background-color: #F1F5F9;
        border-color: #CBD5E1;
        color: #1E293B;
    }
    QPushButton:pressed {
        background-color: #E2E8F0;
    }
"""

REFRESH_BUTTON_STYLE = """
    QPushButton {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
            stop:0 #5B7FFF, stop:1 #7C3AED);
        color: white;
        border: none;
        border-radius: 10px;
        font-size: 14px;
        font-weight: bold;
    }
    QPushButton:hover { 
        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
            stop:0 #4F6FEF, stop:1 #6D28D9);
    }
    QPushButton:pressed {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
            stop:0 #4361EE, stop:1 #5B21B6);
    }
"""

ADD_FOLDER_BUTTON_STYLE = """
    QPushButton {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
            stop:0 #10B981, stop:1 #059669);
        color: white;
        border: none;
        border-radius: 8px;
        font-size: 16px;
        font-weight: bold;
    }
    QPushButton:hover { 
        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
            stop:0 #059669, stop:1 #047857);
    }
    QPushButton:pressed {
        background-color: #047857;
    }
"""

SELECT_FOLDER_BUTTON_STYLE = """
    QPushButton {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
            stop:0 #5B7FFF, stop:1 #7C3AED);
        color: white;
        border: none;
        border-radius: 10px;
        padding: 8px 16px;
        font-size: 13px;
        font-weight: 600;
    }
    QPushButton:hover {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
            stop:0 #4F6FEF, stop:1 #6D28D9);
    }
    QPushButton:pressed {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
            stop:0 #4361EE, stop:1 #5B21B6);
    }
"""

# =============================================================================
# Folder Button Styles (Legacy - kept for compatibility)
# =============================================================================
ROOT_FOLDER_BUTTON_STYLE = """
    QPushButton {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
            stop:0 #5B7FFF, stop:1 #7C3AED);
        color: white;
        border: none;
        border-radius: 12px;
        padding: 10px 20px;
        font-size: 13px;
        font-weight: bold;
    }
    QPushButton:hover {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
            stop:0 #7C3AED, stop:1 #5B7FFF);
    }
"""

FOLDER_BUTTON_STYLE = """
    QPushButton {
        background-color: #FFFFFF;
        color: #1E293B;
        border: 2px solid #E2E8F0;
        border-radius: 12px;
        padding: 10px 20px;
        font-size: 12px;
        font-weight: 500;
    }
    QPushButton:hover {
        background-color: #F0FDF4;
        border-color: #10B981;
    }
"""

FOLDER_BUTTON_DRAG_STYLE = """
    QPushButton {
        background-color: #D1FAE5;
        color: #065F46;
        border: 2px dashed #10B981;
        border-radius: 12px;
        padding: 10px 20px;
        font-size: 12px;
        font-weight: 500;
    }
"""

# =============================================================================
# Thumbnail Widget Styles
# =============================================================================
THUMBNAIL_STYLE = """
    ThumbnailWidget {
        background-color: #FFFFFF;
        border: none;
        border-radius: 12px;
    }
    ThumbnailWidget:hover {
        background-color: #F0FDF4;
        border: 2px solid #10B981;
    }
"""

THUMBNAIL_SELECTED_STYLE = """
    ThumbnailWidget {
        background-color: #EEF2FF;
        border: 2px solid #5B7FFF;
        border-radius: 12px;
    }
    ThumbnailWidget:hover {
        background-color: #E0E7FF;
        border: 2px solid #4F6FEF;
    }
"""

THUMBNAIL_DRAG_OVER_STYLE = """
    ThumbnailWidget {
        background-color: #DBEAFE;
        border: 3px dashed #3B82F6;
        border-radius: 12px;
    }
"""

# =============================================================================
# Frame Styles
# =============================================================================
FOLDERS_FRAME_STYLE = """
    QFrame {
        background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
            stop:0 #FFFFFF, stop:1 #F8FAFC);
        border: 1px solid #E2E8F0;
        border-radius: 16px;
    }
    QLabel {
        border: none;
        background: transparent;
    }
"""

FILES_FRAME_STYLE = """
    QFrame {
        background-color: #FFFFFF;
        border: 1px solid #E2E8F0;
        border-radius: 16px;
    }
    QLabel {
        border: none;
        background: transparent;
    }
"""

# =============================================================================
# Slider Style
# =============================================================================
SIZE_SLIDER_STYLE = """
    QSlider {
        min-height: 24px;
    }
    QSlider::groove:horizontal {
        height: 6px;
        background: #E2E8F0;
        border-radius: 3px;
    }
    QSlider::sub-page:horizontal {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
            stop:0 #5B7FFF, stop:1 #7C3AED);
        border-radius: 3px;
    }
    QSlider::handle:horizontal {
        background: #FFFFFF;
        border: 2px solid #5B7FFF;
        width: 14px;
        height: 14px;
        margin: -5px 0;
        border-radius: 8px;
    }
    QSlider::handle:horizontal:hover {
        border-color: #7C3AED;
        background: #F8FAFC;
    }
"""

# =============================================================================
# Scroll Area Style
# =============================================================================
SCROLL_AREA_STYLE = """
    QScrollArea { 
        border: none; 
        background: transparent; 
    }
    QScrollArea > QWidget > QWidget {
        background: transparent;
    }
    QScrollBar:vertical {
        background: #F1F5F9;
        width: 10px;
        border-radius: 5px;
        margin: 2px;
    }
    QScrollBar::handle:vertical {
        background: #CBD5E1;
        border-radius: 5px;
        min-height: 30px;
    }
    QScrollBar::handle:vertical:hover {
        background: #94A3B8;
    }
    QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
        height: 0px;
    }
    QScrollBar:horizontal {
        background: #F1F5F9;
        height: 10px;
        border-radius: 5px;
        margin: 2px;
    }
    QScrollBar::handle:horizontal {
        background: #CBD5E1;
        border-radius: 5px;
        min-width: 30px;
    }
    QScrollBar::handle:horizontal:hover {
        background: #94A3B8;
    }
    QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {
        width: 0px;
    }
"""

# =============================================================================
# Tooltip Style
# =============================================================================
TOOLTIP_STYLE = """
    QToolTip {
        background-color: #1E293B;
        color: #F8FAFC;
        border: none;
        border-radius: 8px;
        padding: 8px 12px;
        font-size: 12px;
        font-weight: 500;
    }
"""

# Custom hover label style (for widgets that need custom tooltips)
HOVER_LABEL_STYLE = """
    QLabel {
        background-color: #1E293B;
        color: #F8FAFC;
        border: none;
        border-radius: 8px;
        padding: 8px 12px;
        font-size: 12px;
        font-weight: 500;
    }
"""

# =============================================================================
# Context Menu Style
# =============================================================================
CONTEXT_MENU_STYLE = """
    QMenu {
        background-color: #FFFFFF;
        border: 1px solid #E2E8F0;
        border-radius: 8px;
        padding: 6px 4px;
    }
    QMenu::item {
        padding: 8px 20px 8px 12px;
        font-size: 13px;
        color: #1E293B;
        background: transparent;
        border: none;
        border-radius: 6px;
        margin: 2px 4px;
    }
    QMenu::item:selected {
        background-color: #EEF2FF;
        color: #5B7FFF;
    }
    QMenu::item:disabled {
        color: #94A3B8;
    }
    QMenu::separator {
        height: 1px;
        background: #E2E8F0;
        margin: 6px 8px;
    }
"""

# =============================================================================
# Welcome Page Styles
# =============================================================================
WELCOME_TITLE_STYLE = """
    QLabel {
        color: #1E293B;
        font-size: 32px;
        font-weight: bold;
    }
"""

WELCOME_SUBTITLE_STYLE = """
    QLabel {
        color: #64748B;
        font-size: 16px;
    }
"""

WELCOME_CARD_STYLE = """
    QFrame {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
            stop:0 #FFFFFF, stop:1 #F8FAFC);
        border: 1px solid #E2E8F0;
        border-radius: 24px;
    }
"""

# =============================================================================
# Header Styles
# =============================================================================
HEADER_LABEL_STYLE = """
    QLabel {
        color: #1E293B;
        font-size: 14px;
        font-weight: 600;
        border: none;
        background: transparent;
    }
"""

PATH_LABEL_STYLE = """
    QLabel {
        color: #64748B;
        font-size: 12px;
        padding: 6px 12px;
        background-color: #F1F5F9;
        border-radius: 8px;
    }
"""

# =============================================================================
# Splitter Style
# =============================================================================
SPLITTER_STYLE = """
    QSplitter::handle {
        background: #E2E8F0;
        border-radius: 3px;
    }
    QSplitter::handle:hover {
        background: #5B7FFF;
    }
    QSplitter::handle:pressed {
        background: #7C3AED;
    }
"""


# =============================================================================
# Dark Mode Styles
# =============================================================================

DARK_MAIN_WINDOW_STYLE = """
    QMainWindow {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
            stop:0 #1a1a2e, stop:1 #16213e);
    }
"""

DARK_BACK_BUTTON_STYLE = """
    QPushButton {
        background-color: #2d2d44;
        color: #a0a0b0;
        border: 1px solid #3d3d5c;
        border-radius: 8px;
        padding: 8px 16px;
        font-size: 13px;
        font-weight: 600;
    }
    QPushButton:hover { 
        background-color: #3d3d5c;
        border-color: #5d5d7c;
        color: #e0e0e0;
    }
    QPushButton:pressed {
        background-color: #4d4d6c;
    }
"""

DARK_FOLDERS_FRAME_STYLE = """
    QFrame {
        background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
            stop:0 #2d2d44, stop:1 #252538);
        border: 1px solid #3d3d5c;
        border-radius: 16px;
    }
    QLabel {
        border: none;
        background: transparent;
        color: #e0e0e0;
    }
"""

DARK_FILES_FRAME_STYLE = """
    QFrame {
        background-color: #2d2d44;
        border: 1px solid #3d3d5c;
        border-radius: 16px;
    }
    QLabel {
        border: none;
        background: transparent;
        color: #e0e0e0;
    }
"""

DARK_THUMBNAIL_STYLE = """
    ThumbnailWidget {
        background-color: #3d3d5c;
        border: none;
        border-radius: 12px;
    }
    ThumbnailWidget:hover {
        background-color: #4d4d6c;
        border: 2px solid #10B981;
    }
"""

DARK_THUMBNAIL_SELECTED_STYLE = """
    ThumbnailWidget {
        background-color: #3d3d5c;
        border: 2px solid #5B7FFF;
        border-radius: 12px;
    }
    ThumbnailWidget:hover {
        background-color: #4d4d6c;
        border: 2px solid #7C3AED;
    }
"""

DARK_SCROLL_AREA_STYLE = """
    QScrollArea { 
        border: none; 
        background: transparent; 
    }
    QScrollArea > QWidget > QWidget {
        background: transparent;
    }
    QScrollBar:vertical {
        background: #2d2d44;
        width: 10px;
        border-radius: 5px;
        margin: 2px;
    }
    QScrollBar::handle:vertical {
        background: #5d5d7c;
        border-radius: 5px;
        min-height: 30px;
    }
    QScrollBar::handle:vertical:hover {
        background: #7d7d9c;
    }
    QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
        height: 0px;
    }
    QScrollBar:horizontal {
        background: #2d2d44;
        height: 10px;
        border-radius: 5px;
        margin: 2px;
    }
    QScrollBar::handle:horizontal {
        background: #5d5d7c;
        border-radius: 5px;
        min-width: 30px;
    }
    QScrollBar::handle:horizontal:hover {
        background: #7d7d9c;
    }
    QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {
        width: 0px;
    }
"""

DARK_CONTEXT_MENU_STYLE = """
    QMenu {
        background-color: #2d2d44;
        border: 1px solid #3d3d5c;
        border-radius: 8px;
        padding: 6px 4px;
    }
    QMenu::item {
        padding: 8px 20px 8px 12px;
        font-size: 13px;
        color: #e0e0e0;
        background: transparent;
        border: none;
        border-radius: 6px;
        margin: 2px 4px;
    }
    QMenu::item:selected {
        background-color: #3d3d5c;
        color: #7C9AFF;
    }
    QMenu::item:disabled {
        color: #6d6d8c;
    }
    QMenu::separator {
        height: 1px;
        background: #3d3d5c;
        margin: 6px 8px;
    }
"""

DARK_PATH_LABEL_STYLE = """
    QLabel {
        color: #a0a0b0;
        font-size: 12px;
        padding: 6px 12px;
        background-color: #252538;
        border-radius: 8px;
    }
"""

DARK_HEADER_LABEL_STYLE = """
    QLabel {
        color: #e0e0e0;
        font-size: 14px;
        font-weight: 600;
        border: none;
        background: transparent;
    }
"""

DARK_SIZE_SLIDER_STYLE = """
    QSlider {
        min-height: 24px;
    }
    QSlider::groove:horizontal {
        height: 6px;
        background: #3d3d5c;
        border-radius: 3px;
    }
    QSlider::sub-page:horizontal {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
            stop:0 #5B7FFF, stop:1 #7C3AED);
        border-radius: 3px;
    }
    QSlider::handle:horizontal {
        background: #e0e0e0;
        border: 2px solid #5B7FFF;
        width: 14px;
        height: 14px;
        margin: -5px 0;
        border-radius: 8px;
    }
    QSlider::handle:horizontal:hover {
        border-color: #7C3AED;
        background: #ffffff;
    }
"""

DARK_HOVER_LABEL_STYLE = """
    QLabel {
        background-color: #3d3d5c;
        color: #e0e0e0;
        border: 1px solid #5d5d7c;
        border-radius: 8px;
        padding: 8px 12px;
        font-size: 12px;
        font-weight: 500;
    }
"""

DARK_SPLITTER_STYLE = """
    QSplitter::handle {
        background: #3d3d5c;
        border-radius: 3px;
    }
    QSplitter::handle:hover {
        background: #5B7FFF;
    }
    QSplitter::handle:pressed {
        background: #7C3AED;
    }
"""

DARK_WELCOME_CARD_STYLE = """
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

DARK_TOOLTIP_STYLE = """
    QToolTip {
        background-color: #3d3d5c;
        color: #e0e0e0;
        border: 1px solid #5d5d7c;
        border-radius: 8px;
        padding: 8px 12px;
        font-size: 12px;
        font-weight: 500;
    }
"""
