"""
Main application window.
"""

from PyQt6.QtWidgets import QMainWindow, QApplication, QStackedWidget

from .styles import MAIN_WINDOW_STYLE
from .pages import WelcomePage, FileBrowserPage


class MainWindow(QMainWindow):
    """Main application window."""
    
    def __init__(self):
        super().__init__()
        self._init_ui()
    
    def _init_ui(self):
        """Initialize the UI components."""
        from .styles import TOOLTIP_STYLE
        self.setWindowTitle("图片整理")
        self.setMinimumSize(1400, 900)
        self.setStyleSheet(MAIN_WINDOW_STYLE + TOOLTIP_STYLE)
        
        # Stacked widget for page navigation
        self.stack = QStackedWidget()
        
        # Create pages
        self.welcome_page = WelcomePage(self._on_folder_selected)
        self.browser_page = FileBrowserPage(self._go_back)
        
        self.stack.addWidget(self.welcome_page)
        self.stack.addWidget(self.browser_page)
        
        self.setCentralWidget(self.stack)
        self._center_on_screen()
    
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
