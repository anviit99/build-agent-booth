# Custom từng booth chỉ qua `.env.agent`

Kit này dùng **cùng** `selfbooth-agent.exe` cho mọi site. Không fork source, không sửa script — chỉ copy folder kit + một file `.env.agent` riêng mỗi máy.

## Nguyên tắc

1. **Một booth = một `.env.agent`** cạnh `run-agent.cmd` (hoặc `-EnvFile` trỏ file khác).
2. **Không commit** `.env.agent` thật (token, `ROOM_ID`).
3. **`run-agent.ps1` luôn ép `AGENT_MODE=booth`** — không cần (và không nên) đổi mode trong env.
4. Chỉ khác biệt “autodelete” so kit gốc là `AGENT_DELETE_AFTER_UPLOAD=true` — giữ nguyên trừ khi rollback có chủ đích.

## Bắt buộc đổi mỗi site

| Biến | Ý nghĩa |
|------|---------|
| `API_BASE_URL` | URL API prod/staging của brand (`…/api/v1`) |
| `SERVICE_TOKEN` | Token booth (Admin → Cài booth) |
| `ROOM_ID` | UUID phòng — 1 PC = 1 phòng |
| `WATCH_DIR` | Thư mục **cha** X Acquire (watch đệ quy). **Không** dùng `auto` |

Tùy chọn: `WATCH_DIR_2`, `STAFF_PIN`, `RELAY_*` nếu có relay shutter.

## Chất lượng ảnh upload (đổi theo brand / băng thông)

Hai knob **độc lập** — đừng nhầm px với MB:

| Biến | Mặc định kit | Tác dụng |
|------|----------------|----------|
| `AGENT_MAX_PHOTO_EDGE` | `3000` | Cạnh dài tối đa (px). `0` = không resize theo px |
| `AGENT_MAX_PHOTO_BYTES` | `3145728` | **Trần** dung lượng sau nén (bytes). Ảnh lớn hơn → nén/scale **xuống ≤ cap**. `0` = tắt cap |
| `AGENT_JPEG_QUALITY` | `92` | Chất lượng JPEG khi phải nén lại |

**Giá trị `AGENT_MAX_PHOTO_BYTES` thường dùng:**

| Bytes | Gần đúng | Khi nào |
|-------|----------|---------|
| `3145728` | 3 MiB | Mặc định kit HDMI — cân bằng in + upload |
| `4194304` | 4 MiB | Brand muốn file hơn nặng một chút |
| `5242880` | 5 MiB | In lớn / compose cần chi tiết |
| `0` | tắt | Giữ gần file gốc (vẫn có thể bị `EDGE` resize) |

Preview kiosk (`AGENT_PREVIEW_*`) **không** ảnh hưởng file upload — chỉ `/preview/latest.jpg` local.

## Session / X Acquire (cùng source, tune nếu cần)

| Biến | Mặc định | Ghi chú |
|------|----------|---------|
| `AGENT_STICKY_HANDOFF_SEC` | `8` | Ảnh trễ sau End vẫn về phiên cũ |
| `AGENT_SESSION_STRAGGLER_SEC` | `6` | Dump X Acquire sau Start kiosk → phiên trước. Giữ ≤ sticky |
| `AGENT_BACKLOG_MAX_AGE_SEC` | `120` | Bỏ file “cũ” trên đĩa booth |
| `AGENT_BIND_RETRY_MS` | `2000` | Chờ API khi mạng chập |

## Preset nhanh (copy vào `.env.agent`)

**Mặc định kit (3 MiB, 3000px)** — đã có trong `.env.agent.example`:

```env
AGENT_MAX_PHOTO_EDGE=3000
AGENT_MAX_PHOTO_BYTES=3145728
AGENT_JPEG_QUALITY=92
```

**In cao / file nặng hơn (~5 MiB):**

```env
AGENT_MAX_PHOTO_EDGE=3000
AGENT_MAX_PHOTO_BYTES=5242880
AGENT_JPEG_QUALITY=94
```

**Mạng yếu / upload nhanh:**

```env
AGENT_MAX_PHOTO_EDGE=2400
AGENT_MAX_PHOTO_BYTES=2097152
AGENT_JPEG_QUALITY=88
```

**Gần file gốc (cẩn thận dung lượng + thời gian nén):**

```env
AGENT_MAX_PHOTO_EDGE=0
AGENT_MAX_PHOTO_BYTES=0
```

## Triển khai nhiều bên

1. Zip **một** folder kit (exe + script, không kèm `.env.agent` thật).
2. Mỗi booth: giải nén → `copy .env.agent.example .env.agent` → điền 4 biến bắt buộc + preset ảnh.
3. `run-agent.cmd` — banner in `Delete`, `Watch`, `Upload cap` (bytes + edge).
4. Verify: `curl http://127.0.0.1:8791/status` + chụp thử → log `SIZE CAP:` / `COMPRESSED:` nếu file gốc vượt cap.

## Không custom qua env

- Logic handoff, autodelete, spool — cần **exe mới** từ cùng repo.
- Skin kiosk, frame, API domain SPA — deploy FE/API riêng, không nằm trong kit agent.
