# booth-hdmi-xacquire-autodelete — khác biệt & checklist verify

Kit này chỉ khác kit gốc `booth-hdmi-xacquire` ở **một hành vi runtime**: xóa JPG trong `WATCH_DIR` sau khi API nhận ảnh. Cùng `selfbooth-agent.exe`, cùng source `selfbooth-backend/cmd/agent`.

## Khác biệt so với kit gốc

| Mục | Kit gốc | Kit này |
|-----|---------|---------|
| `AGENT_DELETE_AFTER_UPLOAD` | không set (⇒ `false`) | `true` |
| File JPG sau upload OK | giữ trong `WATCH_DIR` | bị xóa, log `DELETED:` |
| `AGENT_LOG_FILE` | không set (console only) | `logs\agent.log` + rotation |
| Scheduled task name | `Selfbooth HDMI XAcquire Agent` | `Selfbooth HDMI XAcquire Agent (autodelete)` |
| Script build | không có | `build-agent.ps1` (test rồi build) |
| Detect / stable / compress / mirror / relay / control HTTP | — | **giống hệt** (+ `/preview/meta` + `/preview/latest.jpg` trên control HTTP khi build agent mới) |
| `AGENT_MAX_PHOTO_EDGE` trong example | — | **3000** (px cạnh dài; không phải 3MB). `0` = tắt resize theo px |
| `AGENT_MAX_PHOTO_BYTES` trong example | — | **3145728** (3 MiB cap, đổi qua env: 5242880 = 5 MiB, `0` = tắt). Ảnh lớn hơn sẽ nén/scale xuống ≤ cap |

Không có `HDMI-XACQUIRE-CHECKLIST.md` riêng: checklist operator (camera, capture card, WATCH_DIR drift, banner, NFR) dùng chung bản ở kit gốc.

## Điều kiện xóa (implement trong `cmd/agent/cleanup.go`)

Xóa chỉ xảy ra khi `uploadResult` là `ok` hoặc `ok_retry` — tức `postPhotoBytes` đã trả thành công.

| Nhánh trong `uploadPhoto` | Log | File |
|---------------------------|-----|------|
| Upload OK lần đầu | `UPLOADED:` → `DELETED:` | xóa |
| Upload OK ở retry | `UPLOADED (retry N):` → `DELETED:` | xóa |
| Kiosk chưa Start | `NO SESSION —` | giữ |
| File chưa ổn định | `STABLE WAIT` | giữ |
| Fail hết retry → spool | `SPOOL AFTER FAIL` | giữ |
| Xóa lỗi (handle bị giữ) | `DELETE FAILED:` | giữ, upload vẫn tính OK |

## Vì sao một tấm ảnh không lên (bảng nhánh từ chối)

Mọi nhánh từ chối đều in log ở mức bình thường — không cần bật `AGENT_DEBUG` mới thấy.

| Nhánh | Log | Bền qua restart? | Xử lý |
|-------|-----|------------------|-------|
| Đã upload thành công trước đó | `SKIP already_uploaded:` | **Có** (lưu `processed-files.json`) | Đúng thì bỏ qua; sai thì `reset-processed.cmd` |
| Tiến trình này đã từ chối (no session) | `SKIP refused_earlier:` | Không (chỉ trong RAM) | Restart agent là xét lại |
| File nằm trên đĩa quá lâu | `SKIP backlog:` | Không | Nới `AGENT_BACKLOG_MAX_AGE_SEC` nếu cần |
| Đang xử lý ở goroutine khác | `SKIP in_flight:` | Không | Bình thường khi fsnotify và scan trùng nhau |
| Kiosk chưa Start | `NO SESSION — ignoring upload` | Không | Bấm Start trước khi chụp |
| Backend không trả lời được | `BIND RETRY` → `BIND GIVE UP` | Không | Kiểm tra mạng / `API_BASE_URL` |

Định danh ảnh dùng **đường dẫn + kích thước + mtime**, không phải riêng đường dẫn. Fuji quay vòng bộ đếm frame nên `DSCF0939.JPG` sẽ quay lại với một tấm khác; khoá theo đường dẫn khiến tấm sau bị nuốt vĩnh viễn (đúng lỗi mà `fix-agent-ingest-photo-drop` xử lý).

Cắt backlog tính theo **thời điểm file xuất hiện trên booth PC** (creation time), không theo `mtime` — `mtime` mang đồng hồ máy ảnh, máy chạy lệch vài giờ sẽ khiến mọi tấm vừa chụp trông như ảnh tồn.

## Đọc counter trên `/status`

```
curl http://127.0.0.1:8791/status
```

| Trường | Nghĩa | Kỳ vọng trong phiên bình thường |
|--------|-------|--------------------------------|
| `skipped_uploaded` | số lần bỏ vì đã upload | `0` |
| `skipped_refused` | số lần bỏ vì tiến trình đã từ chối | `0` |
| `skipped_backlog` | số lần bỏ vì quá tuổi | `0` |
| `skipped_inflight` | trùng lịch detect/scan | nhỏ, vô hại |
| `no_session_drops` | số ảnh chụp khi chưa Start | `0` |
| `bind_retries` | số lần thử lại vì lookup không trả lời được | `0` |
| `uploaded_store_size` | số bản ghi trong store bền | tăng dần, TTL 72h |
| `last_skip_reason` | lý do bỏ ảnh gần nhất | `null` |

## Checklist verify trên booth PC

- [ ] `build-agent.ps1` chạy xong: `go test` pass, `selfbooth-agent.exe` xuất hiện trong folder kit
- [ ] **Kit gốc** (env không có knob): chụp 1 shot → log `UPLOADED`, **không** có `DELETED`, file vẫn còn trong `WATCH_DIR`
- [ ] **Kit này** (`AGENT_DELETE_AFTER_UPLOAD=true`): chụp 1 shot → log `UPLOADED` rồi `DELETED: <file> (<n> bytes)`, file biến khỏi `WATCH_DIR`
- [ ] Kiosk vẫn hiện ảnh trong Latest + strip sau khi file local đã bị xóa
- [ ] `curl http://127.0.0.1:8791/status` → `"delete_after_upload": true` và `"last_delete": "ok: <file>"`
- [ ] Dry-run không session: chụp khi kiosk chưa Start → log `NO SESSION`, file **vẫn còn**
- [ ] Tắt backend rồi chụp: log `UPLOAD FAILED` + spool, file **vẫn còn**
- [ ] `logs\agent.log` có nội dung; sau khi vượt 5MB thấy `agent.log.1`
- [ ] Rollback: đặt `AGENT_DELETE_AFTER_UPLOAD=false`, restart → file không bị xóa nữa (không rebuild)

## Lưu ý về log

`initLogger()` đọc `AGENT_LOG_FILE` từ process env **trước** khi agent load `.env.agent`. Vì vậy log ra file chỉ hoạt động khi chạy qua `run-agent.cmd` / `run-agent.ps1` (script export env rồi mới gọi exe). Chạy `selfbooth-agent.exe -env ...` trực tiếp thì chỉ có log console.

## Kết quả verification thực tế

Đã chạy trên máy dev (2026-07-26), exe build từ `build-agent.ps1`:

- [x] `build-agent.ps1`: `go test ./cmd/agent/` pass, `selfbooth-agent.exe` sinh trong folder kit
- [x] `GET /status` → `"delete_after_upload": true`, `"last_delete": null` khi chưa xóa lần nào
- [x] Chạy qua `run-agent.ps1` → `logs\agent.log` được tạo, dòng đầu `AGENT_LOG_FILE: ... (rotate at 5242880 bytes, keep 3)`
- [x] Drop JPG khi backend không truy cập được → log `NO SESSION — ignoring`, **file vẫn còn** dù knob đang bật

Còn lại phải làm trên booth PC thật (cần backend + kiosk + X Acquire):

- [ ] Upload OK → log `UPLOADED` rồi `DELETED: <file> (<n> bytes)`, file biến khỏi `WATCH_DIR`
- [ ] Kiosk vẫn hiện ảnh trong Latest + strip sau khi file local đã bị xóa
- [ ] `"last_delete": "ok: <file>"` trong `/status`
- [ ] Tắt backend giữa phiên → `UPLOAD FAILED` + spool, file vẫn còn
- [ ] Kit gốc (không có knob) → không có `DELETED`, file vẫn còn
- [ ] Rollback `AGENT_DELETE_AFTER_UPLOAD=false` → không xóa nữa, không rebuild
