"""
PNG/JPG to VTF+VMT Converter - All non-branding images in fireteam project
Writes VTF 7.0 format (RGBA8888, no compression) + matching VMT files.
Automatically pads non-power-of-2 dimensions to next pow2.
Output to coldwar_content/06_实用脚本/materials/ as user-specified standard path.
"""
import struct
from PIL import Image
import os

# ── VTF format constants ──
VTF_SIGNATURE = b"VTF\x00"
VTF_VERSION_MAJOR = 7
VTF_VERSION_MINOR = 0
VTF_HEADER_SIZE = 64
IMAGE_FORMAT_RGBA8888 = 0
TEXTUREFLAGS_NOCOMPRESS = 0x100

# ── Output root (user-specified standard path) ──
OUT_ROOT = r'C:\GMOD开发\战术小队模式\coldwar_content\06_实用脚本\materials'

# ── Source directories (exclude branding) ──
SOURCE_DIRS = [
    # Game content materials
    (r'c:\GMOD开发\战术小队模式\fireteam\gamemodes\fireteam\content\materials\fireteam\factions',
     'fireteam/factions'),

    (r'c:\GMOD开发\战术小队模式\fireteam\gamemodes\fireteam\content\materials\fireteam\items',
     'fireteam/items'),

    (r'c:\GMOD开发\战术小队模式\fireteam\gamemodes\fireteam\content\materials\fireteam\classes',
     'fireteam/classes'),

    # .design assets - Cold War version (icons + decorations)
    (r'c:\GMOD开发\战术小队模式\fireteam\.design\assets\coldwar',
     'fireteam/ui/coldwar'),

    # .design assets - CRT version (legacy)
    (r'c:\GMOD开发\战术小队模式\fireteam\.design\assets',
     'fireteam/ui/design'),
]

def next_pow2(n):
    p = 1
    while p < n:
        p *= 2
    return p

def write_vtf(png_path, vtf_path):
    """Convert an image file to VTF 7.0 (RGBA8888)."""
    img = Image.open(png_path).convert("RGBA")
    width, height = img.size

    # Pad to power of 2
    np2_w = next_pow2(width)
    np2_h = next_pow2(height)
    if np2_w != width or np2_h != height:
        new_img = Image.new("RGBA", (np2_w, np2_h), (0, 0, 0, 0))
        new_img.paste(img, (0, 0))
        img = new_img
        width, height = np2_w, np2_h

    pixels = img.load()

    # Build VTF header (64 bytes, packed)
    header = bytearray()
    header += VTF_SIGNATURE                           # 0:  signature
    header += struct.pack('<I', VTF_VERSION_MAJOR)     # 4:  major
    header += struct.pack('<I', VTF_VERSION_MINOR)     # 8:  minor
    header += struct.pack('<I', VTF_HEADER_SIZE)       # 12: header size
    header += struct.pack('<HH', width, height)        # 16: width, height
    header += struct.pack('<I', TEXTUREFLAGS_NOCOMPRESS) # 20: flags
    header += struct.pack('<HH', 1, 0)                 # 24: numFrames, firstFrame
    header += struct.pack('<I', 0)                     # 28: padding
    header += struct.pack('<3f', 0.0, 0.0, 0.0)        # 32: reflectivity
    header += struct.pack('<I', 0)                     # 44: padding
    header += struct.pack('<f', 0.0)                   # 48: bumpScale
    header += struct.pack('<I', IMAGE_FORMAT_RGBA8888) # 52: source format
    header += struct.pack('<B', 1)                    # 56: numMipLevels
    header += struct.pack('<I', IMAGE_FORMAT_RGBA8888) # 57: lowRes format
    header += struct.pack('<B', 0)                     # 61: lowResWidth
    header += struct.pack('<B', 0)                     # 62: lowResHeight
    header += b'\x00'                                  # 63: pad
    assert len(header) == VTF_HEADER_SIZE

    # Pixel data (bottom-to-top, RGBA8888)
    pixel_data = bytearray()
    for y in range(height - 1, -1, -1):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            pixel_data += struct.pack('4B', r, g, b, a)

    with open(vtf_path, 'wb') as f:
        f.write(header)
        f.write(pixel_data)

    return width, height

def write_vmt(vmt_path, material_path):
    """Write a VMT file referencing the given material path."""
    vmt = f'"UnlitGeneric"\n{{\n    "$basetexture" "{material_path}"\n    "$translucent" "1"\n    "$nolod" "1"\n    "$vertexcolor" "1"\n    "$vertexalpha" "1"\n}}\n'
    with open(vmt_path, 'w', encoding='utf-8') as f:
        f.write(vmt)

def process_dir(src_dir, mat_prefix):
    """Convert all images in src_dir to VTF+VMT in output dir."""
    out_dir = os.path.join(OUT_ROOT, mat_prefix.replace('/', '\\'))
    os.makedirs(out_dir, exist_ok=True)
    count = 0
    for fname in sorted(os.listdir(src_dir)):
        if not fname.lower().endswith(('.png', '.jpg', '.jpeg')):
            continue
        fpath = os.path.join(src_dir, fname)
        if os.path.isdir(fpath):
            continue
        base = os.path.splitext(fname)[0]
        vtf_path = os.path.join(out_dir, base + '.vtf')
        vmt_path = os.path.join(out_dir, base + '.vmt')

        try:
            w, h = write_vtf(fpath, vtf_path)
            mat_path = f"{mat_prefix}/{base}"
            write_vmt(vmt_path, mat_path)
            print(f"  [OK] {fname:<35} -> {base}.vtf ({w}x{h})")
            count += 1
        except Exception as e:
            print(f"  [FAIL] {fname}: {e}")
    return count

if __name__ == '__main__':
    total = 0
    for src_dir, mat_prefix in SOURCE_DIRS:
        if not os.path.exists(src_dir):
            print(f"[SKIP] {src_dir} (not found)")
            continue
        files = [f for f in os.listdir(src_dir) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
        if not files:
            print(f"[SKIP] {src_dir} (no images)")
            continue
        print(f"\n[{mat_prefix}]")
        total += process_dir(src_dir, mat_prefix)

    print(f"\n{'='*50}")
    print(f"Total converted: {total} file(s)")
    print(f"Output root: {OUT_ROOT}")
