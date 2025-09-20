#!/usr/bin/env python3
"""
Script to resize iPhone screenshots to App Store requirements
"""
from PIL import Image
import os
import glob

def resize_screenshot(input_path, output_path, target_size):
    """Resize a screenshot to the target size"""
    try:
        # Open the image
        img = Image.open(input_path)
        
        # Convert to RGB if necessary
        if img.mode != 'RGB':
            img = img.convert('RGB')
        
        # Resize to target size
        resized = img.resize(target_size, Image.Resampling.LANCZOS)
        
        # Save the resized image
        resized.save(output_path, 'PNG', quality=95)
        print(f"✅ Resized {input_path} to {target_size[0]}x{target_size[1]}")
        return True
        
    except Exception as e:
        print(f"❌ Error resizing {input_path}: {e}")
        return False

def main():
    """Resize all screenshots in the current directory"""
    
    # Target sizes for App Store
    target_sizes = [
        (1244, 2688),  # iPhone 6.5" portrait
        (1284, 2778),  # iPhone 6.5" portrait alternative
    ]
    
    # Find all PNG files in current directory
    png_files = glob.glob("*.png")
    
    if not png_files:
        print("❌ No PNG files found in current directory")
        print("Please copy your iPhone 16 Plus screenshots to this directory first")
        return
    
    print(f"Found {len(png_files)} PNG files")
    
    # Create output directory
    os.makedirs("app_store_screenshots", exist_ok=True)
    
    # Resize each screenshot
    for png_file in png_files:
        if "app_store" in png_file.lower():
            continue  # Skip already processed files
            
        for i, size in enumerate(target_sizes):
            # Create output filename
            name, ext = os.path.splitext(png_file)
            output_name = f"app_store_screenshots/{name}_appstore_{size[0]}x{size[1]}{ext}"
            
            # Resize the image
            resize_screenshot(png_file, output_name, size)
    
    print(f"\n✅ All screenshots resized and saved to 'app_store_screenshots/' folder")
    print("You can now upload these to App Store Connect!")

if __name__ == "__main__":
    main()
