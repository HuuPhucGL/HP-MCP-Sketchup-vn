# HP MCP SketchUp (tiếng Việt)

Bộ cài kết nối **Claude** (Claude Desktop, Claude Code) với **SketchUp** qua MCP.
Sau khi cài, anh/chị chỉ cần nói với Claude bằng tiếng Việt, ví dụ *"dựng khối hộp 3x4x2,8 m"*,
*"chụp ảnh mô hình góc iso"*, *"liệt kê các Tag trong file"* — Claude sẽ tự điều khiển SketchUp đang mở.

Bản này do **Nguyễn Hữu Phúc** viết. Giấy phép MIT (xem [LICENSE](LICENSE)). Không dùng mã của bên thứ ba.

## Bộ này gồm những gì

| Thành phần | Nằm ở đâu | Dùng để làm gì |
|---|---|---|
| Plugin SketchUp "HP SketchUp MCP" | `plugin/`, gói sẵn `dist/hp_sketchup_mcp.rbz` | Chạy bên trong SketchUp, mở một "cổng nói chuyện" nội bộ `127.0.0.1:9876` (chỉ máy mình truy cập được) |
| MCP server | `server/server.py` | "Người phiên dịch" giữa Claude và plugin |
| Bộ cài tự động | `CaiDat.bat`, `installer/install.ps1` | Tìm các bản SketchUp đã cài, chép plugin, cài server, đăng ký với Claude |
| Gỡ cài đặt | `GoCai.bat` | Gỡ plugin và bỏ đăng ký |

Claude có 4 công cụ:

- `sketchup_ping` — kiểm tra kết nối, xem phiên bản SketchUp, tên file đang mở.
- `sketchup_model_info` — đơn vị, khung bao (mm), số group/component, danh sách Tag, Scene.
- `sketchup_eval_ruby` — chạy lệnh Ruby của SketchUp (vẽ, sửa, gán vật liệu...). Có tên thao tác thì cả đoạn gom thành **1 lần Undo** (giống UNDO Begin/End trong AutoCAD), lỗi giữa chừng tự hoàn tác.
- `sketchup_screenshot` — chụp ảnh khung nhìn (iso, top, front, back, left, right) để Claude tự kiểm tra.

## Phiên bản SketchUp hỗ trợ

| SketchUp | Ruby bên trong | Tình trạng |
|---|---|---|
| 2023 | 2.7 | **Đã chạy thử** trên Windows 11 |
| 2017, 2018 | 2.2 | Viết tương thích, **cần kiểm tra** |
| 2019, 2020 | 2.5 | Viết tương thích, **cần kiểm tra** |
| 2021, 2022 | 2.7 | Viết tương thích, **cần kiểm tra** |
| 2024, 2025 | 3.2 | Viết tương thích, **cần kiểm tra** |
| 2016 trở về trước | — | Không hỗ trợ |

Bản Make 2017 (miễn phí) cũng nạp được plugin — **cần kiểm tra**. SketchUp bản web/Go không chạy plugin, không dùng được.
Ai đã chạy được trên bản "cần kiểm tra", xin báo lại qua mục Issues để cập nhật bảng.

## Yêu cầu

- Windows 10/11.
- SketchUp 2017 trở lên (bản cài trên máy).
- **Python 3.10 trở lên** (tải ở python.org, khi cài nhớ tích ô *Add python.exe to PATH*), hoặc [uv](https://docs.astral.sh/uv/).
- Claude Desktop hoặc Claude Code.

## Cài đặt từng bước

### Bước 1. Tải bộ cài về

- Cách dễ: trên trang GitHub này bấm nút xanh **Code → Download ZIP**, giải nén ra ví dụ `C:\HP-MCP-Sketchup-vn`
  (nên để đường dẫn **không dấu, không khoảng trắng lạ**).
- Hoặc dùng Git:

  ```powershell
  git clone https://github.com/HuuPhucGL/HP-MCP-Sketchup-vn.git C:\HP-MCP-Sketchup-vn
  ```

### Bước 2. Đóng SketchUp, chạy bộ cài

Đóng hết SketchUp, rồi **bấm đúp `CaiDat.bat`**. Bộ cài sẽ:

1. Tìm các bản SketchUp đã cài thật (có file `SketchUp.exe`).
2. Chép plugin vào `%APPDATA%\SketchUp\SketchUp 20xx\SketchUp\Plugins` của **từng bản**. Plugin cũ (nếu có) được sao lưu vào `%LOCALAPPDATA%\HP-MCP-Sketchup\_backup\`.
3. Cài MCP server vào `%LOCALAPPDATA%\HP-MCP-Sketchup` (tạo môi trường Python riêng, cài thư viện `mcp`).
4. Đăng ký MCP tên `sketchup` với Claude Code (lệnh `claude mcp add --scope user`) và Claude Desktop (file `claude_desktop_config.json`, có sao lưu `.bak-...` trước khi sửa).

Cuối cùng màn hình báo **HOAN TAT**.

Tuỳ chọn khi chạy bằng PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File installer\install.ps1 -Phienban 2024,2025
```

| Tuỳ chọn | Ý nghĩa |
|---|---|
| `-Phienban 2024,2025` | Bộ cài không tự tìm thấy bản nào đó (cài ổ khác) thì chỉ định tay |
| `-ChiPlugin` | Chỉ chép plugin |
| `-BoQuaClaude` | Cài plugin + server nhưng không đăng ký Claude |
| `-GoCai` | Gỡ (giống `GoCai.bat`) |

### Bước 3. Mở SketchUp, kiểm tra plugin

1. Mở SketchUp, chọn một mẫu (template) ở màn hình Welcome. Plugin chỉ chạy sau bước này.
2. Vào menu **Extensions → HP MCP → Trang thai**: phải hiện *"HP MCP dang chay tai 127.0.0.1:9876"*.
3. Chưa thấy menu: vào **Window/Extensions → Extension Manager**, xem "HP SketchUp MCP" đã bật chưa.

### Bước 4. Khởi động lại Claude và thử

Tắt hẳn Claude Desktop (cả biểu tượng ở khay đồng hồ) rồi mở lại, hoặc mở phiên Claude Code mới. Gõ:

> Kiểm tra kết nối SketchUp

Claude trả về phiên bản SketchUp và tên file là thành công.

## Cài tay (không dùng bộ cài)

1. **Plugin**: trong SketchUp vào **Extension Manager → Install Extension**, chọn `dist/hp_sketchup_mcp.rbz`.
2. **Server**: mở PowerShell trong thư mục bộ cài:

   ```powershell
   python -m venv "$env:LOCALAPPDATA\HP-MCP-Sketchup\.venv"
   ```

   ```powershell
   & "$env:LOCALAPPDATA\HP-MCP-Sketchup\.venv\Scripts\python.exe" -m pip install -r server\requirements.txt
   ```

3. **Đăng ký với Claude Code**:

   ```powershell
   claude mcp add --scope user sketchup -- "$env:LOCALAPPDATA\HP-MCP-Sketchup\.venv\Scripts\python.exe" "C:\HP-MCP-Sketchup-vn\server\server.py"
   ```

   Với Claude Desktop, thêm vào `%APPDATA%\Claude\claude_desktop_config.json`:

   ```json
   {
     "mcpServers": {
       "sketchup": {
         "command": "C:\\Users\\<ten-may>\\AppData\\Local\\HP-MCP-Sketchup\\.venv\\Scripts\\python.exe",
         "args": ["C:\\HP-MCP-Sketchup-vn\\server\\server.py"]
       }
     }
   }
   ```

## Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| Claude báo "Khong ket noi duoc SketchUp tai 127.0.0.1:9876" | SketchUp chưa mở, còn ở màn hình Welcome, hoặc plugin đang tắt (Extensions → HP MCP → Bat ket noi) |
| Mở 2 cửa sổ/2 bản SketchUp cùng lúc | Chỉ bản mở trước giữ được cổng 9876. Claude điều khiển bản đó |
| Cổng 9876 bị phần mềm khác chiếm | Ruby Console sẽ báo "Khong mo duoc cong 9876". Tắt phần mềm kia |
| Claude không thấy công cụ sketchup | Khởi động lại Claude sau khi cài. Kiểm tra bằng `claude mcp list` |
| Bộ cài báo thiếu Python | Cài Python 3.10+ từ python.org, tích *Add python.exe to PATH*, chạy lại `CaiDat.bat` |

## An toàn

- Plugin chỉ nghe kết nối từ **chính máy này** (`127.0.0.1`), máy khác trong mạng không truy cập được.
- `sketchup_eval_ruby` chạy được mọi lệnh Ruby, nghĩa là có thể xóa đối tượng hoặc ghi file. Hãy để Claude hỏi trước khi xóa/lưu đè, và lưu file `.skp` thường xuyên. Mọi thay đổi có tên thao tác đều **Undo (Ctrl+Z) được một lần**.
- Không cần tài khoản, mật khẩu hay khóa API nào.

## Đóng gói lại file .rbz (cho người sửa mã)

```powershell
python installer\build_rbz.py
```

## Giấy phép

MIT — xem [LICENSE](LICENSE). Lịch sử thay đổi: [CHANGELOG.md](CHANGELOG.md).
