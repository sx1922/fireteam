"""Scan all non-branding images and report their dimensions."""
from PIL import Image
import os

# Directories to scan (exclude branding)
SCAN_DIRS = [
    r'c:\GMOD开发\战术小队模式\fireteam\gamemodes\fireteam\content\materials\fireteam\factions',
    r'c:\GMOD开发\战术小队模式\fireteam\gamemodes\fireteam\content\materials\fireteam\items',
    r'c:\GMOD开发\战术小队模式\fireteam\gamemodes\fireteam\content\materials\fireteam\classes',
    r'c:\GMOD开发\战术小队模式\fireteam\setting_packs\coldwar\artwork',
    r'c:\GMOD开发\战术小队模式\fireteam\.design\assets',
    r'c:\GMOD开发\战术小队模式\fireteam\.design\assets\coldwar',
]

def is_pow2(n):
    return n > 0 and (n & (n - 1)) == 0

print(f"{'File':<45} {'Size':>12} {'Pow2?':>8}")
print("-" * 68)

for scan_dir in SCAN_DIRS:
    if not os.path.exists(scan_dir):
        continue
    for fname in sorted(os.listdir(scan_dir)):
        if not fname.lower().endswith(('.png', '.jpg', '.jpeg')):
            continue
        fpath = os.path.join(scan_dir, fname)
        try:
            img = Image.open(fpath)
            w, h = img.size
            rel = os.path.relpath(fpath, r'c:\GMOD开发\战术小队模式\fireteam')
            pow2 = is_pow2(w) and is_pow2(h)
            print(f"{rel:<45} {w}x{h:>6} {'YES' if pow2 else 'NO':>8}")
        except Exception as e:
            print(f"{fpath}: ERROR {e}")
