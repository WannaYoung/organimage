"""
Application constants and configuration.
"""

# Supported image file extensions
IMAGE_EXTENSIONS = {
    '.png', '.jpg', '.jpeg', '.gif', '.bmp', 
    '.webp', '.tiff', '.ico', '.svg'
}

# Default thumbnail size
DEFAULT_THUMB_SIZE = 120
MIN_THUMB_SIZE = 60
MAX_THUMB_SIZE = 200

# Folder button settings
FOLDER_BUTTON_SIZE = 90
FOLDER_BUTTON_SPACING = 6
FOLDER_MIN_COLUMNS = 3

# Files grid settings
FILES_GRID_SPACING = 6
FILES_GRID_MARGIN = 4

# Thumbnail cache settings
THUMBNAIL_CACHE_MAX_SIZE = 500

# Debounce delays (milliseconds)
RESIZE_DEBOUNCE_MS = 200
SLIDER_DEBOUNCE_MS = 150

# UI Colors
COLORS = {
    'primary': '#4CAF50',
    'primary_hover': '#45a049',
    'secondary': '#2196F3',
    'secondary_hover': '#1976D2',
    'background': '#ffffff',
    'surface': '#fafafa',
    'border': '#e0e0e0',
    'text': '#333333',
    'text_secondary': '#666666',
}
