"""
Utility functions for file operations.
"""

import logging
import os
import re
import shutil
import subprocess
import sys
from typing import List, Tuple, Optional

try:
    from send2trash import send2trash
    HAS_SEND2TRASH = True
except ImportError:
    HAS_SEND2TRASH = False

from .constants import IMAGE_EXTENSIONS

# Setup logging
logger = logging.getLogger(__name__)


def is_image_file(filepath: str) -> bool:
    """Check if a file is a supported image format."""
    ext = os.path.splitext(filepath)[1].lower()
    return ext in IMAGE_EXTENSIONS


def get_image_files(directory: str) -> List[str]:
    """Get all image files in a directory."""
    if not os.path.isdir(directory):
        return []
    
    files = []
    try:
        for item in sorted(os.listdir(directory)):
            item_path = os.path.join(directory, item)
            if os.path.isfile(item_path) and is_image_file(item_path):
                files.append(item_path)
    except PermissionError:
        pass
    
    return files


def get_subdirectories(directory: str) -> List[str]:
    """Get all subdirectories in a directory."""
    if not os.path.isdir(directory):
        return []
    
    dirs = []
    try:
        for item in sorted(os.listdir(directory)):
            item_path = os.path.join(directory, item)
            if os.path.isdir(item_path):
                dirs.append(item_path)
    except PermissionError:
        pass
    
    return dirs


def count_files_in_directory(directory: str) -> int:
    """Count the number of files in a directory."""
    try:
        return len([f for f in os.listdir(directory) 
                   if os.path.isfile(os.path.join(directory, f))])
    except (PermissionError, FileNotFoundError):
        return 0


def get_next_file_number(folder_path: str, folder_name: str) -> int:
    """
    Get the next available file number for naming convention.
    Files are named as: 文件夹名 (001).ext, 文件夹名 (002).ext, etc.
    """
    # Match pattern: 文件夹名 (001).ext
    pattern = re.compile(rf"^{re.escape(folder_name)} \((\d{{3}})\)\.[^.]+$")
    max_num = 0
    
    try:
        for filename in os.listdir(folder_path):
            match = pattern.match(filename)
            if match:
                num = int(match.group(1))
                max_num = max(max_num, num)
    except (PermissionError, FileNotFoundError):
        pass
    
    return max_num + 1


def move_file_to_folder(file_path: str, folder_path: str) -> Tuple[bool, str]:
    """
    Move a file to a folder with automatic renaming.
    New name format: 文件夹名 (001).ext
    Returns (success, new_path or error_message).
    """
    if not os.path.exists(file_path):
        return False, "源文件不存在"
    
    if not os.path.isdir(folder_path):
        return False, "目标文件夹不存在"
    
    folder_name = os.path.basename(folder_path)
    _, ext = os.path.splitext(file_path)
    
    next_num = get_next_file_number(folder_path, folder_name)
    new_name = f"{folder_name} ({next_num:03d}){ext}"
    new_path = os.path.join(folder_path, new_name)
    
    try:
        shutil.move(file_path, new_path)
        return True, new_path
    except Exception as e:
        return False, str(e)


def rename_folder_with_contents(
    folder_path: str, 
    new_name: str
) -> Tuple[bool, str]:
    """
    Rename a folder and ALL image files inside with sequential numbering.
    All image files will be renamed to: 新名称 (001).ext, 新名称 (002).ext, etc.
    Returns (success, new_folder_path or error_message).
    Includes rollback on failure.
    """
    old_name = os.path.basename(folder_path)
    parent_dir = os.path.dirname(folder_path)
    new_folder_path = os.path.join(parent_dir, new_name)
    
    if old_name == new_name:
        return True, folder_path
    
    if os.path.exists(new_folder_path):
        return False, f"文件夹 '{new_name}' 已存在"
    
    # Track original names for rollback
    original_names: List[Tuple[str, str]] = []  # (original_name, current_name)
    temp_names: List[Tuple[str, str, str]] = []  # (temp_name, ext, original_name)
    
    try:
        # Get all image files and sort them
        image_files = []
        for filename in sorted(os.listdir(folder_path)):
            file_path = os.path.join(folder_path, filename)
            if os.path.isfile(file_path) and is_image_file(file_path):
                image_files.append(filename)
        
        # First pass: rename to temp names to avoid conflicts
        for i, filename in enumerate(image_files):
            ext = os.path.splitext(filename)[1]
            temp_name = f"__temp_rename_{i:05d}{ext}"
            old_file = os.path.join(folder_path, filename)
            temp_file = os.path.join(folder_path, temp_name)
            os.rename(old_file, temp_file)
            temp_names.append((temp_name, ext, filename))
            original_names.append((filename, temp_name))
        
        # Second pass: rename to final names
        final_names: List[Tuple[str, str]] = []  # (temp_name, final_name)
        for i, (temp_name, ext, orig_name) in enumerate(temp_names):
            new_filename = f"{new_name} ({i+1:03d}){ext}"
            temp_file = os.path.join(folder_path, temp_name)
            new_file = os.path.join(folder_path, new_filename)
            os.rename(temp_file, new_file)
            final_names.append((temp_name, new_filename))
            # Update tracking
            for j, (orig, curr) in enumerate(original_names):
                if curr == temp_name:
                    original_names[j] = (orig, new_filename)
                    break
        
        # Rename the folder itself
        os.rename(folder_path, new_folder_path)
        return True, new_folder_path
        
    except Exception as e:
        logger.error(f"Rename failed, attempting rollback: {e}")
        # Rollback: restore original file names
        try:
            for orig_name, curr_name in original_names:
                if orig_name != curr_name:
                    curr_file = os.path.join(folder_path, curr_name)
                    orig_file = os.path.join(folder_path, orig_name)
                    if os.path.exists(curr_file) and not os.path.exists(orig_file):
                        os.rename(curr_file, orig_file)
            logger.info("Rollback completed successfully")
        except Exception as rollback_error:
            logger.error(f"Rollback failed: {rollback_error}")
        return False, str(e)


def create_folder(parent_path: str, folder_name: str) -> Tuple[bool, str]:
    """
    Create a new folder.
    Returns (success, new_folder_path or error_message).
    """
    new_path = os.path.join(parent_path, folder_name)
    
    if os.path.exists(new_path):
        return False, f"文件夹 '{folder_name}' 已存在"
    
    try:
        os.makedirs(new_path)
        return True, new_path
    except Exception as e:
        return False, str(e)


def delete_file(file_path: str) -> Tuple[bool, str]:
    """
    Move a file to system trash (recycle bin).
    Falls back to permanent deletion if send2trash is not available.
    Returns (success, message).
    """
    if not os.path.exists(file_path):
        return False, "文件不存在"
    
    try:
        if HAS_SEND2TRASH:
            send2trash(file_path)
            return True, "已移至回收站"
        else:
            # Fallback to permanent deletion
            os.remove(file_path)
            logger.warning("send2trash not available, file permanently deleted")
            return True, "删除成功（永久删除）"
    except Exception as e:
        logger.error(f"Failed to delete file: {e}")
        return False, str(e)


def delete_folder(folder_path: str) -> Tuple[bool, str]:
    """
    Move a folder and all its contents to system trash (recycle bin).
    Falls back to permanent deletion if send2trash is not available.
    Returns (success, message).
    """
    if not os.path.exists(folder_path):
        return False, "文件夹不存在"
    
    try:
        if HAS_SEND2TRASH:
            send2trash(folder_path)
            return True, "已移至回收站"
        else:
            # Fallback to permanent deletion
            shutil.rmtree(folder_path)
            logger.warning("send2trash not available, folder permanently deleted")
            return True, "删除成功（永久删除）"
    except Exception as e:
        logger.error(f"Failed to delete folder: {e}")
        return False, str(e)


def rename_file(file_path: str, new_name: str) -> Tuple[bool, str]:
    """
    Rename a file (keep in same directory).
    Returns (success, new_path or error_message).
    """
    if not os.path.exists(file_path):
        return False, "文件不存在"
    
    parent_dir = os.path.dirname(file_path)
    new_path = os.path.join(parent_dir, new_name)
    
    if os.path.exists(new_path):
        return False, f"文件 '{new_name}' 已存在"
    
    try:
        os.rename(file_path, new_path)
        return True, new_path
    except Exception as e:
        return False, str(e)


def reorder_files_by_list(file_paths: List[str], folder_name: str) -> Tuple[bool, str]:
    """
    Reorder files by renaming them according to the given order.
    Files will be renamed to: 文件夹名 (001).ext, 文件夹名 (002).ext, etc.
    Returns (success, message).
    Includes rollback on failure.
    """
    if not file_paths:
        return True, "没有文件需要重命名"
    
    # Track original paths for rollback: (original_path, current_path)
    original_mappings: List[Tuple[str, str]] = []
    
    try:
        # First pass: rename all to temp names to avoid conflicts
        temp_mappings: List[Tuple[str, str, str, str]] = []  # (temp_path, ext, parent_dir, orig_path)
        for i, file_path in enumerate(file_paths):
            if not os.path.exists(file_path):
                continue
            ext = os.path.splitext(file_path)[1]
            parent_dir = os.path.dirname(file_path)
            temp_name = f"__temp_reorder_{i:05d}{ext}"
            temp_path = os.path.join(parent_dir, temp_name)
            os.rename(file_path, temp_path)
            temp_mappings.append((temp_path, ext, parent_dir, file_path))
            original_mappings.append((file_path, temp_path))
        
        # Second pass: rename to final names with new order
        for i, (temp_path, ext, parent_dir, orig_path) in enumerate(temp_mappings):
            new_name = f"{folder_name} ({i+1:03d}){ext}"
            new_path = os.path.join(parent_dir, new_name)
            os.rename(temp_path, new_path)
            # Update tracking
            for j, (orig, curr) in enumerate(original_mappings):
                if curr == temp_path:
                    original_mappings[j] = (orig, new_path)
                    break
        
        return True, f"已重新排序 {len(temp_mappings)} 个文件"
    except Exception as e:
        logger.error(f"Reorder failed, attempting rollback: {e}")
        # Rollback: restore original file names
        try:
            for orig_path, curr_path in original_mappings:
                if orig_path != curr_path:
                    if os.path.exists(curr_path) and not os.path.exists(orig_path):
                        os.rename(curr_path, orig_path)
            logger.info("Rollback completed successfully")
        except Exception as rollback_error:
            logger.error(f"Rollback failed: {rollback_error}")
        return False, str(e)


def open_in_finder(path: str) -> Tuple[bool, str]:
    """
    Open the file or folder location in system file manager.
    Returns (success, message).
    """
    if not os.path.exists(path):
        return False, "路径不存在"
    
    try:
        if sys.platform == "darwin":  # macOS
            if os.path.isfile(path):
                # Reveal file in Finder
                subprocess.run(["open", "-R", path], check=True)
            else:
                # Open folder
                subprocess.run(["open", path], check=True)
        elif sys.platform == "win32":  # Windows
            if os.path.isfile(path):
                subprocess.run(["explorer", "/select,", path], check=True)
            else:
                subprocess.run(["explorer", path], check=True)
        else:  # Linux
            parent = os.path.dirname(path) if os.path.isfile(path) else path
            subprocess.run(["xdg-open", parent], check=True)
        return True, "已打开"
    except Exception as e:
        return False, str(e)
