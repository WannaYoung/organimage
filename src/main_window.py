"""
Main application window.
"""

from PyQt6.QtWidgets import QMainWindow, QApplication, QStackedWidget

from .styles import MAIN_WINDOW_STYLE, DARK_MAIN_WINDOW_STYLE, TOOLTIP_STYLE, DARK_TOOLTIP_STYLE
from .pages import WelcomePage, FileBrowserPage
from .theme_manager import get_theme_manager


class MainWindow(QMainWindow):
    """Main application window."""
    
    def __init__(self):
        super().__init__()
        self._theme_manager = get_theme_manager()
        self._theme_manager.register_callback(self._on_theme_changed)
        self._init_ui()
        self._apply_theme()
    
    def _init_ui(self):
        """Initialize the UI components."""
        self.setWindowTitle("图片整理")
        self.setMinimumSize(1400, 900)
        
        # Stacked widget for page navigation
        self.stack = QStackedWidget()
        
        # Create pages
        self.welcome_page = WelcomePage(self._on_folder_selected)
        self.browser_page = FileBrowserPage(self._go_back)
        
        self.stack.addWidget(self.welcome_page)
        self.stack.addWidget(self.browser_page)
        
        self.setCentralWidget(self.stack)
        self._center_on_screen()
    
    def _apply_theme(self):
        """Apply current theme to main window."""
        is_dark = self._theme_manager.is_dark_mode
        if is_dark:
            self.setStyleSheet(DARK_MAIN_WINDOW_STYLE + DARK_TOOLTIP_STYLE)
        else:
            self.setStyleSheet(MAIN_WINDOW_STYLE + TOOLTIP_STYLE)
        
        # Notify pages to update their themes
        self.welcome_page.apply_theme(is_dark)
        self.browser_page.apply_theme(is_dark)
    
    def _on_theme_changed(self, is_dark: bool):
        """Handle theme change."""
        self._apply_theme()
    
    def _center_on_screen(self):
        """Center the window on the screen."""
        screen = QApplication.primaryScreen().geometry()
        size = self.geometry()
        self.move(
            (screen.width() - size.width()) // 2,
            (screen.height() - size.height()) // 2
        )
    
    def _on_folder_selected(self, folder_path: str):
        """Handle folder selection from welcome page."""
        self.browser_page.set_root_path(folder_path)
        self.stack.setCurrentIndex(1)
    
    def _go_back(self):
        """Go back to welcome page."""
        self.stack.setCurrentIndex(0)
    
    def closeEvent(self, event):
        """Clean up on close."""
        self._theme_manager.unregister_callback(self._on_theme_changed)
        super().closeEvent(event)
