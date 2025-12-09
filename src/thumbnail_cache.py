"""
Thumbnail cache and async loader for performance optimization.
Uses QRunnable + QThreadPool for safe thread management.
"""

import os
import threading
from collections import OrderedDict
from typing import Optional, Dict

from PyQt6.QtCore import QObject, QRunnable, QThreadPool, pyqtSignal, QSize, Qt
from PyQt6.QtGui import QPixmap, QImage, QImageReader

from .constants import THUMBNAIL_CACHE_MAX_SIZE


# Thread-safe LRU cache for thumbnails
class ThumbnailCache:
    """Thread-safe LRU cache for thumbnail pixmaps."""
    
    def __init__(self, max_size: int = THUMBNAIL_CACHE_MAX_SIZE):
        self._cache: OrderedDict[str, QPixmap] = OrderedDict()
        self._max_size = max_size
        self._lock = threading.Lock()
    
    def get(self, key: str) -> Optional[QPixmap]:
        """Get cached pixmap, moves to end for LRU."""
        with self._lock:
            if key in self._cache:
                self._cache.move_to_end(key)
                return self._cache[key]
            return None
    
    def put(self, key: str, pixmap: QPixmap):
        """Store pixmap in cache with LRU eviction."""
        with self._lock:
            if key in self._cache:
                self._cache.move_to_end(key)
            else:
                if len(self._cache) >= self._max_size:
                    # Remove oldest item (first item in OrderedDict)
                    self._cache.popitem(last=False)
                self._cache[key] = pixmap
    
    def clear(self):
        """Clear all cached items."""
        with self._lock:
            self._cache.clear()


# Global cache instance
_thumbnail_cache = ThumbnailCache()


def get_cached_thumbnail(key: str) -> Optional[QPixmap]:
    """Get cached pixmap."""
    return _thumbnail_cache.get(key)


def put_cached_thumbnail(key: str, pixmap: QPixmap):
    """Store pixmap in cache."""
    _thumbnail_cache.put(key, pixmap)


def make_cache_key(file_path: str, size: int) -> str:
    """Create cache key from path and size."""
    try:
        mtime = os.path.getmtime(file_path) if os.path.exists(file_path) else 0
    except OSError:
        mtime = 0
    return f"{file_path}:{size}:{mtime}"


class ThumbnailLoaderSignals(QObject):
    """Signals for ThumbnailLoader - must be QObject subclass."""
    image_ready = pyqtSignal(str, QImage, int)  # file_path, image, size


class ThumbnailLoader(QRunnable):
    """
    Async thumbnail loader using QRunnable + QThreadPool.
    This is safer than QThread as the thread pool manages lifecycle.
    """
    
    def __init__(self, file_path: str, size: int):
        super().__init__()
        self.file_path = file_path
        self.size = size
        self._cancelled = False
        self.signals = ThumbnailLoaderSignals()
        # Auto-delete when done
        self.setAutoDelete(True)
    
    @property
    def image_ready(self):
        """Convenience property to access signal."""
        return self.signals.image_ready
    
    def cancel(self):
        """Cancel the loading operation."""
        self._cancelled = True
    
    def run(self):
        """Load image in thread pool (QImage only, not QPixmap)."""
        if self._cancelled:
            return
        
        try:
            # Load image using QImageReader
            reader = QImageReader(self.file_path)
            reader.setAutoTransform(True)
            
            if self._cancelled:
                return
            
            # Set scaled size for faster loading
            original_size = reader.size()
            if original_size.isValid() and original_size.width() > 0 and original_size.height() > 0:
                scale_factor = min(
                    self.size / original_size.width(),
                    self.size / original_size.height()
                )
                if scale_factor < 1:
                    new_width = int(original_size.width() * scale_factor)
                    new_height = int(original_size.height() * scale_factor)
                    reader.setScaledSize(QSize(new_width, new_height))
            
            if self._cancelled:
                return
            
            image = reader.read()
            
            if self._cancelled:
                return
            
            # Final scale if needed (QImage operations are thread-safe)
            if not image.isNull():
                if image.width() > self.size or image.height() > self.size:
                    image = image.scaled(
                        self.size, self.size,
                        Qt.AspectRatioMode.KeepAspectRatio,
                        Qt.TransformationMode.SmoothTransformation
                    )
            
            if not self._cancelled:
                # Emit QImage - conversion to QPixmap happens in main thread
                self.signals.image_ready.emit(self.file_path, image, self.size)
        except Exception:
            # Silently ignore errors in background thread
            pass


# Global thread pool for thumbnail loading
_thread_pool: Optional[QThreadPool] = None


def get_thread_pool() -> QThreadPool:
    """Get or create the global thread pool for thumbnail loading."""
    global _thread_pool
    if _thread_pool is None:
        _thread_pool = QThreadPool.globalInstance()
        # Limit concurrent threads to avoid overwhelming the system
        _thread_pool.setMaxThreadCount(4)
    return _thread_pool


def start_thumbnail_loader(loader: ThumbnailLoader):
    """Start a thumbnail loader in the thread pool."""
    get_thread_pool().start(loader)
