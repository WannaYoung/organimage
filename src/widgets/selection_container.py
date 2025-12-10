"""
Selection container widget with rubber band (lasso) selection support.
"""

from typing import List, Callable, Optional

from PyQt6.QtCore import Qt, QPoint, QRect, pyqtSignal
from PyQt6.QtGui import QPainter, QColor, QPen, QMouseEvent
from PyQt6.QtWidgets import QWidget, QGridLayout, QRubberBand


class SelectionContainer(QWidget):
    """Container widget that supports rubber band selection of child widgets."""
    
    # Signal emitted when selection changes: list of selected widget indices
    selection_changed = pyqtSignal(list)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setStyleSheet("background: transparent; border: none;")
        
        # Rubber band for visual selection
        self._rubber_band: Optional[QRubberBand] = None
        self._selection_origin: Optional[QPoint] = None
        self._is_selecting = False
        
        # Callback to get thumbnail widgets
        self._get_thumbnails: Optional[Callable] = None
        
        # Callback to handle selection
        self._on_selection: Optional[Callable] = None
    
    def set_thumbnail_provider(self, callback: Callable):
        """Set callback to get list of thumbnail widgets."""
        self._get_thumbnails = callback
    
    def set_selection_handler(self, callback: Callable):
        """Set callback to handle selection changes."""
        self._on_selection = callback
    
    def mousePressEvent(self, event: QMouseEvent):
        """Start rubber band selection on left click."""
        if event.button() == Qt.MouseButton.LeftButton:
            # Check if clicking on empty space (not on a child widget)
            child = self.childAt(event.pos())
            if child is None or child == self:
                self._selection_origin = event.pos()
                self._is_selecting = True
                
                if self._rubber_band is None:
                    self._rubber_band = QRubberBand(QRubberBand.Shape.Rectangle, self)
                
                self._rubber_band.setGeometry(QRect(self._selection_origin, self._selection_origin))
                self._rubber_band.show()
                
                # Clear selection if not holding Ctrl/Cmd
                if not (event.modifiers() & Qt.KeyboardModifier.ControlModifier):
                    if self._on_selection:
                        self._on_selection([], clear=True)
                
                event.accept()
                return
        
        super().mousePressEvent(event)
    
    def mouseMoveEvent(self, event: QMouseEvent):
        """Update rubber band during selection."""
        if self._is_selecting and self._selection_origin is not None:
            current_pos = event.pos()
            
            # Calculate selection rectangle
            rect = QRect(self._selection_origin, current_pos).normalized()
            self._rubber_band.setGeometry(rect)
            
            # Find widgets that intersect with selection
            self._update_selection(rect, event.modifiers() & Qt.KeyboardModifier.ControlModifier)
            
            event.accept()
            return
        
        super().mouseMoveEvent(event)
    
    def mouseReleaseEvent(self, event: QMouseEvent):
        """Finish rubber band selection."""
        if event.button() == Qt.MouseButton.LeftButton and self._is_selecting:
            self._is_selecting = False
            
            if self._rubber_band:
                self._rubber_band.hide()
            
            self._selection_origin = None
            event.accept()
            return
        
        super().mouseReleaseEvent(event)
    
    def _update_selection(self, selection_rect: QRect, add_to_selection: bool):
        """Update selection based on rubber band rectangle."""
        if not self._get_thumbnails:
            return
        
        thumbnails = self._get_thumbnails()
        selected_indices = []
        
        for i, thumb in enumerate(thumbnails):
            # Get widget geometry relative to this container
            thumb_rect = thumb.geometry()
            
            # Check if thumbnail intersects with selection rectangle
            if selection_rect.intersects(thumb_rect):
                selected_indices.append(i)
        
        if self._on_selection:
            self._on_selection(selected_indices, clear=not add_to_selection)
