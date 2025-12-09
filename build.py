#!/usr/bin/env python3
"""
Build script for creating standalone executables.

Usage:
    python build.py          # Build for current platform
    python build.py --clean  # Clean build artifacts first
"""

import os
import sys
import shutil
import subprocess
import argparse


def clean_build():
    """Remove build artifacts."""
    dirs_to_remove = ['build', 'dist', '__pycache__']
    files_to_remove = ['*.pyc', '*.pyo', '*.spec.bak']
    
    for dir_name in dirs_to_remove:
        if os.path.exists(dir_name):
            print(f"Removing {dir_name}/...")
            shutil.rmtree(dir_name)
    
    # Clean __pycache__ in subdirectories
    for root, dirs, files in os.walk('.'):
        for d in dirs:
            if d == '__pycache__':
                path = os.path.join(root, d)
                print(f"Removing {path}/...")
                shutil.rmtree(path)


def build():
    """Build the application."""
    print(f"Building for {sys.platform}...")
    print("-" * 50)
    
    # Use the spec file
    cmd = [
        sys.executable, '-m', 'PyInstaller',
        '--clean',
        '--noconfirm',
        'build.spec'
    ]
    
    result = subprocess.run(cmd)
    
    if result.returncode == 0:
        print("-" * 50)
        print("✅ Build successful!")
        if sys.platform == 'darwin':
            print("   Output: dist/图片整理.app")
            print("\n   To run: open dist/图片整理.app")
            print("   To install: drag to /Applications folder")
        else:
            print("   Output: dist/图片整理.exe")
    else:
        print("❌ Build failed!")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description='Build Image Organizer')
    parser.add_argument('--clean', action='store_true', help='Clean build artifacts first')
    parser.add_argument('--clean-only', action='store_true', help='Only clean, do not build')
    args = parser.parse_args()
    
    if args.clean or args.clean_only:
        clean_build()
    
    if not args.clean_only:
        build()


if __name__ == '__main__':
    main()
