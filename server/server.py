"""HP SketchUp MCP server.

Cong dung : Cau noi giua Claude (MCP, stdio) va plugin HP SketchUp MCP
            chay ben trong SketchUp (TCP 127.0.0.1:9876, JSON 1 dong).
Ngay viet : 2026-11-11
"""
import json
import os
import socket
import itertools

from mcp.server.fastmcp import FastMCP, Image

HOST = "127.0.0.1"
PORT = int(os.environ.get("HP_SKETCHUP_PORT", "9876"))
_ids = itertools.count(1)

mcp = FastMCP("sketchup")


def _call(method: str, params: dict | None = None, timeout: float = 120.0):
    """Gui 1 lenh toi SketchUp va cho ket qua."""
    req = {"id": next(_ids), "method": method, "params": params or {}}
    try:
        s = socket.create_connection((HOST, PORT), timeout=5)
    except OSError as e:
        raise RuntimeError(
            "Khong ket noi duoc SketchUp tai 127.0.0.1:%d (%s). Kiem tra: SketchUp da mo chua, "
            "extension 'HP SketchUp MCP' da bat chua (Extensions > HP MCP > Bat ket noi)." % (PORT, e)
        )
    with s:
        s.settimeout(timeout)
        s.sendall((json.dumps(req) + "\n").encode("utf-8"))
        buf = b""
        while b"\n" not in buf:
            chunk = s.recv(1 << 16)
            if not chunk:
                break
            buf += chunk
    if not buf:
        raise RuntimeError("SketchUp dong ket noi ma khong tra ket qua.")
    resp = json.loads(buf.split(b"\n", 1)[0].decode("utf-8"))
    if not resp.get("ok"):
        bt = "\n".join(resp.get("backtrace") or [])
        raise RuntimeError(f"Loi trong SketchUp: {resp.get('error')}\n{bt}".strip())
    return resp.get("result")


@mcp.tool()
def sketchup_ping() -> dict:
    """Kiem tra ket noi SketchUp: tra ve phien ban SketchUp, plugin, ten file dang mo."""
    return _call("ping", timeout=10)


@mcp.tool()
def sketchup_model_info() -> dict:
    """Thong tin mo hinh dang mo: don vi, khung bao (mm), so group/component, danh sach Tag, Scene."""
    return _call("model_info", timeout=30)


@mcp.tool()
def sketchup_eval_ruby(code: str, operation_name: str | None = None, timeout_s: float = 300) -> dict:
    """Chay doan ma Ruby (SketchUp Ruby API) trong SketchUp va tra ve gia tri cuoi + noi dung puts.

    - Don vi noi bo SketchUp la inch: luon dung 100.mm, 2.75.m ... khi nhap kich thuoc.
    - Truyen operation_name (vd "Dung tuong tang 1") de gom toan bo thay doi thanh 1 lan Undo;
      neu loi giua chung thi tu dong hoan tac phan da lam.
    - Bien local duoc giu lai giua cac lan goi.
    """
    params = {"code": code}
    if operation_name:
        params["operation"] = operation_name
    return _call("eval_ruby", params, timeout=timeout_s)


@mcp.tool()
def sketchup_screenshot(view: str = "iso", width: int = 1280, height: int = 800,
                        zoom_extents: bool = True, perspective: bool | None = None) -> Image:
    """Chup anh khung nhin SketchUp de kiem tra mo hinh.

    view: current | iso | iso_back | top | front | back | left | right
    """
    res = _call("screenshot", {"view": view, "width": width, "height": height,
                               "zoom_extents": zoom_extents, "perspective": perspective}, timeout=60)
    path = res["path"]
    with open(path, "rb") as f:
        data = f.read()
    try:
        os.remove(path)
    except OSError:
        pass
    return Image(data=data, format="png")


if __name__ == "__main__":
    mcp.run()
