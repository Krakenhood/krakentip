#!/usr/bin/env python3
"""python3 tools/package.py: builds dist/Krakentip-<version>.zip, ready to unzip
into the game's Interface\\AddOns folder. It holds a Krakentip folder with the
.toc, every file the .toc lists, the textures in media/, the README and the
LICENSE, nothing else."""
import os, re, sys, zipfile

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
toc_path = os.path.join(root, 'Krakentip.toc')
with open(toc_path, encoding='utf-8') as fh:
    toc = fh.read()
version = (re.search(r'^## Version:\s*(\S+)', toc, re.M) or [None, 'dev'])[1]
files = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith('#')]
missing = [f for f in files if not os.path.isfile(os.path.join(root, f))]
if missing:
    sys.exit('missing files the .toc lists: ' + ', '.join(missing))
os.makedirs(os.path.join(root, 'dist'), exist_ok=True)
out = os.path.join(root, 'dist', f'Krakentip-{version}.zip')
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    media = sorted('media/' + f for f in os.listdir(os.path.join(root, 'media')) if f.endswith('.tga'))
    if not media:
        sys.exit('no textures in media/: run node tools/media.js')
    for name in ['Krakentip.toc'] + files + media + ['README.md', 'LICENSE']:
        z.write(os.path.join(root, name), 'Krakentip/' + name)
print('wrote', os.path.relpath(out, root))
