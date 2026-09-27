"""Diffs each (<id> off, <id> on) screenshot pair from tool/ab_capture.sh.

Usage: python tool/pair_diff.py <out-dir> <feature-id>
Prints, per stop: mean |ΔRGB|, the % of pixels that changed by more than 24,
and the changed region. The HUD (top-left) is masked: its numbers change
every frame.
"""
import glob, os, sys
import numpy as np
from PIL import Image

d, fid = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(d, '*.png')))
for off in [f for f in files if f'{fid}_off' in f]:
    on = [f for f in files if f[len(d) + 4:] == off[len(d) + 4:].replace(f'{fid}_off', f'{fid}_on')]
    if not on:
        print('missing pair for', off)
        continue
    a = np.asarray(Image.open(off).convert('RGB')).astype(int)
    b = np.asarray(Image.open(on[0]).convert('RGB')).astype(int)
    diff = np.abs(a - b).max(axis=2)
    h, w = diff.shape
    diff[: int(h * 0.16), : int(w * 0.5)] = 0
    ys, xs = np.nonzero(diff > 24)
    where = f'rows {ys.min()}-{ys.max()} cols {xs.min()}-{xs.max()}' if len(ys) else ''
    print(f'{os.path.basename(off)[3:]:<60} mean {diff.mean():5.2f}  >24: {(diff > 24).mean() * 100:5.2f}%  {where}')
