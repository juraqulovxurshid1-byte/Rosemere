#!/usr/bin/env python3
"""
AGGRESSIVE background stripper for game sprites.
Auto-detects background color by sampling image corners/edges,
then removes that color (and similar colors) from the entire image.
"""
import os
import sys
from PIL import Image
from collections import Counter

INPUT_DIR = "Rosemere/art_v2"

def quantize_color(r, g, b, step=16):
    return (r // step * step, g // step * step, b // step * step)

def get_rgba(pixels, x, y):
    """Safely get RGBA, handling both RGB and RGBA modes."""
    p = pixels[x, y]
    if len(p) == 4:
        return p[0], p[1], p[2], p[3]
    else:
        return p[0], p[1], p[2], 255

def set_rgba(pixels, x, y, r, g, b, a):
    """Safely set pixel, handling both RGB and RGBA modes."""
    try:
        if len(pixels[x, y]) == 4:
            pixels[x, y] = (r, g, b, a)
        else:
            pixels[x, y] = (r, g, b)
    except:
        pixels[x, y] = (r, g, b, a)

def get_dominant_edge_colors(img, tolerance=16):
    """Sample edges of image and find the most common color(s)."""
    pixels = img.load()
    w, h = img.size
    
    edge_colors = Counter()
    margin = int(min(w, h) * 0.15)
    
    # Sample all four edges thoroughly
    for x in range(0, w, 3):
        for y in [0, h-1]:
            r, g, b, a = get_rgba(pixels, x, y)
            if a > 30:
                edge_colors[quantize_color(r, g, b, 16)] += 1
    
    for y in range(0, h, 3):
        for x in [0, w-1]:
            r, g, b, a = get_rgba(pixels, x, y)
            if a > 30:
                edge_colors[quantize_color(r, g, b, 16)] += 1
    
    # Sample corner regions (50x50 blocks in each corner)
    corner_size = min(50, w//4, h//4)
    for x in range(0, corner_size, 3):
        for y in range(0, corner_size, 3):
            r, g, b, a = get_rgba(pixels, x, y)
            if a > 30:
                edge_colors[quantize_color(r, g, b, 16)] += 1
            r, g, b, a = get_rgba(pixels, w-1-x, y)
            if a > 30:
                edge_colors[quantize_color(r, g, b, 16)] += 1
            r, g, b, a = get_rgba(pixels, x, h-1-y)
            if a > 30:
                edge_colors[quantize_color(r, g, b, 16)] += 1
            r, g, b, a = get_rgba(pixels, w-1-x, h-1-y)
            if a > 30:
                edge_colors[quantize_color(r, g, b, 16)] += 1
    
    most_common = edge_colors.most_common(3)
    if not most_common:
        return []
    
    bg_colors = []
    for (r, g, b), count in most_common:
        if count > 20:
            bg_colors.append({'r': r, 'g': g, 'b': b, 'tolerance': 50})
    
    return bg_colors

def is_similar_to_bg(r, g, b, bg_colors):
    for bg in bg_colors:
        tol = bg['tolerance']
        if (abs(r - bg['r']) <= tol and 
            abs(g - bg['g']) <= tol and 
            abs(b - bg['b']) <= tol):
            return True
    return False

def process_image(filepath):
    """Auto-detect and remove background from a PNG."""
    filename = os.path.basename(filepath)
    print(f"  Processing: {filename}")
    
    img = Image.open(filepath)
    # Ensure RGBA mode
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    pixels = img.load()
    width, height = img.size
    
    # Step 1: Auto-detect background colors from edges
    bg_colors = get_dominant_edge_colors(img)
    
    if not bg_colors:
        print(f"    ⚠ No dominant edge color found, skipping")
        return False
    
    colors_str = ", ".join([f"({bg['r']},{bg['g']},{bg['b']})" for bg in bg_colors])
    print(f"    Detected bg colors: {colors_str}")
    
    # Step 2: Aggressively remove matching colors
    changed_count = 0
    total_pixels = width * height
    
    for y in range(height):
        for x in range(width):
            r, g, b, a = get_rgba(pixels, x, y)
            
            if a < 15:
                continue
            
            is_bg = is_similar_to_bg(r, g, b, bg_colors)
            
            # Also catch nearly-white isolated pixels (AI artifacts)
            brightness = (r + g + b) / 3
            if not is_bg and brightness > 235:
                is_bg = True
            
            if is_bg:
                set_rgba(pixels, x, y, 0, 0, 0, 0)
                changed_count += 1
    
    # Step 3: Save as RGBA PNG
    img = img.convert('RGBA')
    img.save(filepath, "PNG")
    
    pct = (changed_count / total_pixels) * 100
    print(f"    Changed {changed_count}/{total_pixels} pixels ({pct:.1f}%)")
    return changed_count > 0

def main():
    if not os.path.isdir(INPUT_DIR):
        print(f"Error: Directory '{INPUT_DIR}' not found!")
        sys.exit(1)
    
    print(f"Processing PNGs in: {INPUT_DIR}")
    print("=" * 55)
    
    png_files = sorted([f for f in os.listdir(INPUT_DIR) if f.lower().endswith(".png")])
    print(f"Found {len(png_files)} PNG files")
    print("=" * 55)
    
    processed = 0
    skipped = 0
    
    for filename in png_files:
        filepath = os.path.join(INPUT_DIR, filename)
        try:
            if process_image(filepath):
                processed += 1
            else:
                skipped += 1
        except Exception as e:
            import traceback
            print(f"    ERROR: {e}")
            traceback.print_exc()
            skipped += 1
    
    print("=" * 55)
    print(f"Done! Processed: {processed}, Skipped: {skipped}")

if __name__ == "__main__":
    main()
