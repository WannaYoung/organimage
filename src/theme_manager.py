"""
Theme manager for handling light/dark mode switching.
"""

import sys
from typing import Optional, Callable, List

from PyQt6.QtCore import QObject, pyqtSignal
from PyQt6.QtWidgets import QApplication
from PyQt6.QtGui import QPalette, QColor

from .utils import get_dark_mode_preference, set_dark_mode_preference


def is_system_dark_mode() -> bool:
    """Check if system is in dark mode."""
    if sys.platform == "darwin":
        try:
            import subprocess
            result = subprocess.run(
                ['defaults', 'read', '-g', 'AppleInterfaceStyle'],
                capture_output=True, text=True
            )
            return result.stdout.strip().lower() == 'dark'
        except Exception:
            pass
    elif sys.platform == "win32":
        try:
            import winreg
            key = winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            )
            value, _ = winreg.QueryValueEx(key, "AppsUseLightTheme")
            return value == 0
        except Exception:
            pass
    
    # Default to light mode
    return False


class ThemeManager(QObject):
    """Manages application theme (light/dark mode)."""
    
    theme_changed = pyqtSignal(bool)  # Emits True for dark mode
    
    _instance: Optional['ThemeManager'] = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        super().__init__()
        self._initialized = True
        self._dark_mode = False
        self._callbacks: List[Callable[[bool], None]] = []
        
        # Load preference
        pref = get_dark_mode_preference()
        if pref is None:
            # Follow system
            self._dark_mode = is_system_dark_mode()
        else:
            self._dark_mode = pref
    
    @property
    def is_dark_mode(self) -> bool:
        """Get current dark mode state."""
        return self._dark_mode
    
    def set_dark_mode(self, dark: bool, save: bool = True):
        """Set dark mode state."""
        if self._dark_mode != dark:
            self._dark_mode = dark
            if save:
                set_dark_mode_preference(dark)
            self.theme_changed.emit(dark)
            for callback in self._callbacks:
                callback(dark)
    
    def toggle_dark_mode(self):
        """Toggle between light and dark mode."""
        self.set_dark_mode(not self._dark_mode)
    
    def follow_system(self):
        """Follow system theme setting."""
        set_dark_mode_preference(None)
        self.set_dark_mode(is_system_dark_mode(), save=False)
    
    def register_callback(self, callback: Callable[[bool], None]):
        """Register a callback to be called when theme changes."""
        if callback not in self._callbacks:
            self._callbacks.append(callback)
    
    def unregister_callback(self, callback: Callable[[bool], None]):
        """Unregister a theme change callback."""
        if callback in self._callbacks:
            self._callbacks.remove(callback)


# Global instance
def get_theme_manager() -> ThemeManager:
    """Get the global theme manager instance."""
    return ThemeManager()
