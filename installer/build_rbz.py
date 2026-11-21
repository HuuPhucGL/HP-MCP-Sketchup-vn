"""Dong goi plugin thanh dist/hp_sketchup_mcp.rbz (file zip, duong dan dung dau /).
Cach dung: python installer/build_rbz.py
"""
import pathlib, zipfile
root = pathlib.Path(__file__).resolve().parent.parent
src = root / "plugin"
out = root / "dist" / "hp_sketchup_mcp.rbz"
out.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for p in sorted(src.rglob("*")):
        if p.is_file():
            z.write(p, p.relative_to(src).as_posix())
print(out, [n for n in zipfile.ZipFile(out).namelist()])