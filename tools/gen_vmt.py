"""
Generate VMT material files for each VTF texture.
VMT is a plain-text KeyValues format that references the VTF.
"""
import os

VMT_TEMPLATE = '''"UnlitGeneric"
{{
    "$basetexture" "fireteam/ui/coldwar/{name}"
    "$translucent" "1"
    "$ignorez" "0"
    "$vertexcolor" "1"
    "$vertexalpha" "1"
    "$nolod" "1"
}}
'''

OUTPUT_DIR = r'c:\GMOD开发\战术小队模式\fireteam\materials\fireteam\ui\coldwar'

VTF_NAMES = [
    'corner-stencil',
    'divider-stencil',
    'icon-backpack',
    'icon-class',
    'icon-commander',
    'icon-squad',
    'icon-tacmap',
    'icon-voice',
]

count = 0
for name in VTF_NAMES:
    vmt_path = os.path.join(OUTPUT_DIR, name + '.vmt')
    with open(vmt_path, 'w', encoding='utf-8') as f:
        f.write(VMT_TEMPLATE.format(name=name))
    count += 1
    print(f"[OK] {name}.vmt")

print(f"\nGenerated {count} VMT files in {OUTPUT_DIR}")
