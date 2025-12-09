"""
Application entry point and initialization.
"""

import sys

from PyQt6.QtWidgets import QApplication

from .main_window import MainWindow


def create_app() -> QApplication:
    """Create and configure the application."""
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    app.setApplicationName("图片整理")
    app.setApplicationVersion("1.0.0")
    return app


def run():
    """Run the application."""
    app = create_app()
    
    window = MainWindow()
    window.show()
    
    sys.exit(app.exec())
