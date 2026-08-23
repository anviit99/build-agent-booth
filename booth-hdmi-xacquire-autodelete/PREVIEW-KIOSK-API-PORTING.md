# HDMI X Acquire — Porting Guide: Kiosk Preview + API Config

> **Mục đích:** Mang sang dự án photobooth **base từ Harrords/selfbooth** đã chạy kit  
> `setup/booth-hdmi-xacquire-autodelete`, nhưng **chưa đủ** chức năng preview trên kiosk.  
> **Giả định:** Agent kit đã build mới (có `/preview/*` + `preview_seq` multipart).  
> **Phạm vi sửa trên dự án đích:** chủ yếu **kiosk FE** + **API/config live-view & photo payload**.  
> **Không cần** sửa lại logic autodelete / watch folder nếu kit đã chạy đúng.

Nguồn tham chiếu trong repo Harrords:

| Thành phần | Path |
|------------|------|
| Kit | `setup/booth-hdmi-xacquire-autodelete/` |
| Agent preview | `harrords-backend/cmd/agent/preview.go`, `control.go`, `main.go` (`uploadPhoto`) |
| API photo + preview_url | `harrords-backend/internal/handlers/photos.go`, `models/models.go` |
| Live view config | `harrords-backend/internal/handlers/live_view_settings.go`, `GET /config` |
| Kiosk ShootStage | `harrords_fe/src/routes/kiosk.tsx` |
| Loopback fetch (Chrome LNA) | `harrords_fe/src/lib/loopback-fetch.ts` |
| OpenSpec gốc | `openspec/changes/booth-capture-preview-perf/` |

---

## 1. Mục tiêu UX

Sau khi guest bấm **nút chụp trên thân máy** (HDMI path, không soft-shutter Space):

1. Latest hiện **loading** (“Đang chờ ảnh…”) khi agent detect JPG.
2. Latest paint **local preview** từ `http://127.0.0.1:8791/preview/latest.jpg` **trước** khi upload xong.
3. Strip có ô optimistic `local:{seq}` rồi **promote in-place** khi `NEW_PHOTO` / poll mang `preview_seq`.
4. Sau `UPLOADED` → agent **DELETED** file X Acquire: UI **không mất ảnh** (preview RAM + URL server).
5. Live view = **webcam/HDMI capture card** (`live_view_mode=webcam`), không phụ thuộc fuji-bridge `:8787`.

---

## 2. Kiến trúc (2 đường ảnh)

```
┌─────────────┐   HDMI    ┌──────────────┐
│ Fujifilm    │──────────▶│ Capture card │──▶ getUserMedia (kiosk live)
│ body shutter│           └──────────────┘
└──────┬──────┘
       │ X Acquire drop JPG
       ▼
┌──────────────────────────────────────────┐
│ Agent :8791 (kit autodelete)             │
│  watch WATCH_DIR → stable →              │
│  publishLocalPreview (RAM, seq++)        │
│  POST /sessions/{id}/photos + preview_seq│
│  UPLOADED → DELETE file (disk only)      │
└───────────────┬──────────────────────────┘
                │
     ┌──────────┴──────────┐
     ▼                     ▼
 GET /preview/meta      API + Hub NEW_PHOTO
 GET /preview/latest.jpg   preview_url, thumb_url, preview_seq
     │                     │
     └──────────┬──────────┘
                ▼
         Kiosk ShootStage
         Latest: localPreview ‖ previewUrl ‖ thumbUrl ‖ url
         Strip: thumb (sau promote)
```

| | Live viewfinder | Still Latest / strip |
|--|-----------------|----------------------|
| Nguồn | Webcam UVC (HDMI) | Agent `:8791` rồi server |
| Config | `live_view_mode=webcam`, `tether_stream_url=""` | Poll `/preview/meta` |
| Spacebar | **Không** soft-shutter (body only) | — |

---

## 3. Checklist “dự án đích thiếu gì?”

Chạy trên **booth PC** (cùng máy kiosk):

```powershell
curl.exe -s http://127.0.0.1:8791/preview/meta
curl.exe -s http://127.0.0.1:8791/status
curl.exe -s https://<YOUR_DOMAIN>/config
```

| Kết quả | Ý nghĩa | Việc cần làm |
|---------|---------|--------------|
| `/preview/meta` → `{"seq":…}` | Agent preview OK | Không rebuild kit (trừ khi seq không tăng khi drop JPG) |
| `/status` không có `preview_seq` | Agent cũ | Copy `selfbooth-agent.exe` mới từ kit / rebuild |
| `/config` → `live_view_mode: tether` + `:8787` | Kiosk đang path USB | Set DB/settings `webcam` + clear tether URL; **không** set `TETHER_MJPEG_URL` env |
| Kiosk Network không gọi `:8791` | FE chưa poll agent | Port kiosk (mục 5) |
| Chrome blocked / LNA warning | Public HTTPS → loopback | `loopbackFetch` + Allow Local network (mục 6) |
| Upload OK nhưng Latest tắt sau ~15s | Thiếu promote / REST poll / sticky | Port handoff + poll backup (mục 5) |
| Photo JSON thiếu `preview_url` / `preview_seq` | API chưa đủ | Port API (mục 4) |

---

## 4. API / config cần có (dự án đích)

### 4.1 Live view public config

**Contract kiosk đọc:** `GET /config` (hoặc tương đương) trả:

```json
{
  "live_view_mode": "webcam",
  "tether_stream_url": "",
  "live_view_source": "settings"
}
```

Harrords reference: `live_view_settings.go`

- Settings key: `booth_live_view` → `{"live_view_mode":"webcam","tether_stream_url":""}`
- Priority: env `TETHER_MJPEG_URL` **thắng** DB → nếu env còn URL `:8787` thì kiosk mãi tether. **Xóa/empty env đó** trên server booth HDMI.
- Admin (auth required): `PATCH /api/v1/settings/live-view` body  
  `{"live_view_mode":"webcam","tether_stream_url":""}`  
  (hoặc SQL `booth_live_view` bên dưới nếu không có admin token trên booth)

SQL ví dụ (Postgres):

```sql
INSERT INTO settings (key, value)
VALUES (
  'booth_live_view',
  '{"live_view_mode":"webcam","tether_stream_url":""}'::jsonb
)
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value, updated_at = now();
```

### 4.2 Upload photo — nhận & echo `preview_seq`

Agent gửi multipart field `preview_seq` (int64 > 0).

API MUST:

1. Parse `preview_seq` từ form.
2. Lưu vào model photo (field optional OK).
3. Trả trong JSON create **và** Hub event `NEW_PHOTO`:
   - `preview_seq`
   - `preview_url` (nếu có local derivatives / LocalRoot)
   - `thumb_url` (strip)
   - `url` / `signed_url`

Harrords:

```go
// photos.go — PostForm "preview_seq" → photo.PreviewSeq
// models.Photo: PreviewURL, PreviewSeq
// Broadcast NEW_PHOTO with full photo object
```

Route preview tier (nếu dùng): `GET /api/v1/photos/{id}/preview`  
Kiosk resolve bằng cùng helper URL như thumb.

### 4.3 List session photos (REST backup)

`GET /sessions/{id}/photos?sign=1&limit=…` items MUST có cùng shape (`preview_url`, `preview_seq`, `thumb_url`) để poll promote khi WS miss.

### 4.4 Session bind (agent)

Agent cần **phiên đang mở** cho `ROOM_ID`:

- Kiosk Start / walk-in → session `room_id` = booth `ROOM_ID`
- Không session → log `NO SESSION` / `ACTIVE SESSION HTTP 404` → không upload (preview RAM vẫn có thể tăng seq trên agent mới)

---

## 5. Kiosk FE cần port (chi tiết)

### 5.1 Files mang / port

| File | Việc |
|------|------|
| `src/lib/loopback-fetch.ts` | **Copy nguyên** — `targetAddressSpace: "loopback"` |
| `src/routes/kiosk.tsx` | Port các khối ShootStage bên dưới (hoặc diff tương đương) |
| `src/lib/api.ts` | `BoothConfig.live_view_mode`, `getBoothConfig`, optional live-view PATCH helpers |

### 5.2 Constants / bases

```ts
const AGENT_CONTROL_BASE = "http://127.0.0.1:8791"; // MUST match kit AGENT_CONTROL_ADDR
const PREVIEW_META_POLL_MS =
  Number(import.meta.env.VITE_PREVIEW_META_POLL_MS) || 1000; // ≥ 1000
const PREVIEW_ORPHAN_TTL_MS = 15_000;
const INGEST_WAIT_BUDGET_MS = 12_000;
const INGEST_STATUS_POLL_MS = 1500;
```

Mọi `fetch` tới `127.0.0.1:8791` / `:8787` → dùng `loopbackFetch`, không dùng `fetch` trần.

### 5.3 Chọn webcam vs tether

```ts
const tetherUrl = booth?.tether_stream_url?.trim() || "";
const mode = booth?.live_view_mode ?? "auto";
const preferTether =
  !tetherFailed && (mode === "tether" || mode === "auto") && tetherUrl.length > 0;
const useWebcam = !preferTether;
```

- **Webcam:** live = `getUserMedia`; preview poll = `AGENT_CONTROL_BASE`; **không** gọi fuji `:8787/live/*`.
- **Tether:** preview poll = bridge base từ `tether_stream_url` (`:8787`).

### 5.4 Poll `/preview/meta` (local-first)

Khi ShootStage mount:

1. `base = useWebcam ? AGENT_CONTROL_BASE : bridgeBaseFromTether(...)`
2. Poll `GET ${base}/preview/meta` ≥1s, `cache: "no-store"`, qua `loopbackFetch`.
3. **Tick đầu:** chỉ baseline `previewSeqRef = seq` (không paint stale).
4. Khi `seq > previewSeqRef`:
   - `localPreviewUrl = ${base}/preview/latest.jpg?seq=${seq}`
   - Append optimistic strip: `id = local:${seq}`, `url/thumbUrl = previewUrl`, `preview_seq = seq`
5. Fail soft nếu agent down (không crash session).

### 5.5 Promote `local:*` khi `NEW_PHOTO` / poll

```ts
// Ưu tiên match preview_seq → local:{N}
// Fallback: promote oldest local:* nếu API chưa echo preview_seq
```

Candidate Latest:

```ts
localPreviewUrl || photo?.previewUrl || photo?.thumbUrl || photo?.url
```

Strip: giữ **thumb** server sau promote (không full 4–8MB).

### 5.6 Sticky Latest + loading UX

- **Không** clear `shownSrc` về empty khi orphan purge tạm thời (tránh “hiện rồi tắt”).
- `loading` overlay khi:
  - Space `waitingJpg` / flash (tether), **hoặc**
  - Webcam: `/status` đổi `last_detected_file` → `ingestWaiting` (budget ~12s), **hoặc**
  - Candidate URL chưa decode xong (`paintPending` → “Đang tải ảnh…”).

### 5.7 REST poll luôn bật (kể cả WS open)

Đừng `if (sessionWsOpen) return` hoàn toàn. Webcam hay miss `NEW_PHOTO` trong khi WS “open” → orphan TTL xóa list. Poll `listSessionPhotos(..., { sign: true })` làm backup; merge + promote locals.

### 5.8 Webcam Spacebar

Giữ: Space **không** soft-shutter trên webcam (body shutter + X Acquire). Copy UI nhắc bấm thân máy.

### 5.9 Agent banner

Poll `GET :8791/status` (không chỉ `/health`) để lấy `watch_ok`, `last_detected_file`, `preview_seq`. Banner nếu unreachable / `watch_ok=false`. Nhắc Chrome Allow Local network.

---

## 6. Chrome Local Network Access (bắt buộc trên booth)

Kiosk HTTPS public → `http://127.0.0.1:8791` bị Chrome LNA.

1. Code: mọi request loopback dùng `loopbackFetch` (`targetAddressSpace: "loopback"`).
2. Agent CORS: `Access-Control-Allow-Origin: *` + `Access-Control-Allow-Private-Network: true` (kit đã có).
3. Operator: Chrome → **Allow** Local network cho origin kiosk  
   (`chrome://settings/content/localNetworkAccess`).
4. Hard refresh sau Allow.

Không Allow → meta/preview bị chặn → Latest chậm/chỉ sau upload hoặc trống.

---

## 7. Autodelete vs list trên màn hình

| Thành phần | Sau `DELETED` file X Acquire |
|------------|------------------------------|
| Agent `/preview/latest.jpg` | Còn (buffer RAM đến seq mới) |
| Strip/Latest sau promote | URL **server** — không phụ thuộc disk booth |
| Rủi ro | Chỉ `local:*` + agent restart trước promote; hoặc orphan purge khi không có `NEW_PHOTO` |

→ List **không** bị “xóa theo file” nếu promote/API ổn. Verify: log `UPLOADED` → `DELETED` mà Latest/strip vẫn còn ảnh.

---

## 8. Kit env (đã dùng — chỉ đối chiếu)

File: `setup/booth-hdmi-xacquire-autodelete/.env.agent` (từ `.env.agent.example`)

```env
API_BASE_URL=https://<YOUR_API>/api/v1
SERVICE_TOKEN=...
ROOM_ID=<uuid phòng kiosk>
WATCH_DIR=C:\Users\<Booth>\Documents\FUJIFILM\XAcquire
AGENT_CONTROL_ADDR=127.0.0.1:8791
AGENT_MAX_PHOTO_EDGE=3000
AGENT_MIRROR_PHOTOS=true
AGENT_DELETE_AFTER_UPLOAD=true
RELAY_MODE=none
```

- `ROOM_ID` **khớp** query kiosk `?room_id=`.
- Không chạy 2 agent cùng `WATCH_DIR`.
- Sau sửa agent: `stop-agent.cmd` → xóa `%LOCALAPPDATA%\selfbooth\processed-files.json` nếu backlog “đã processed” → `run-agent.cmd`.

---

## 9. Verify trên booth (copy-paste)

```powershell
# 1) Agent
curl.exe -s http://127.0.0.1:8791/status
# expect: watch_ok true, preview_seq number, delete_after_upload true

# 2) Config
curl.exe -s https://<DOMAIN>/config
# expect: live_view_mode webcam, tether_stream_url ""

# 3) Kiosk: Start ShootStage + Allow LNA + body shutter
# DevTools: :8791/preview/meta 200; Latest loading → ảnh; strip tăng
# Log agent: DETECTED/SCANNED → UPLOADED → DELETED
```

Pass khi:

- [ ] Latest &lt; ~1–2s sau file ổn định (local preview), không empty im
- [ ] Loading hiện khi đang chờ
- [ ] Sau DELETED ảnh vẫn trên Latest/strip
- [ ] Network strip dùng `/thumb` (hoặc thumb_url), panel ưu tiên local rồi `/preview`
- [ ] Không còn request `:8787` khi webcam mode

---

## 10. Non-goals (không làm trên dự án đích nếu kit đã OK)

- Viết lại X Acquire / watch / autodelete
- Bắt buộc fuji-bridge USB soft-shutter trên booth HDMI
- Đổi gallery mobile thumb policy (~480)
- Bind agent control ra ngoài loopback

---

## 11. Thứ tự implement gợi ý (target project)

1. Confirm agent `/preview/meta` + `/status` trên booth.
2. Set `live_view_mode=webcam` (DB/API); clear `TETHER_MJPEG_URL`.
3. API: `preview_seq` form + echo trên create/`NEW_PHOTO`/list; thêm `preview_url` nếu có LocalRoot.
4. Copy `loopback-fetch.ts`; wire kiosk ShootStage (mục 5).
5. Deploy FE; Allow LNA; verify mục 9.

---

## 12. Map symbol nhanh (Harrords → tìm trên project kia)

| Harrords | Vai trò |
|----------|---------|
| `useWebcam` | Nhánh HDMI |
| `AGENT_CONTROL_BASE` | `http://127.0.0.1:8791` |
| `loopbackFetch` / `warmLoopbackAccess` | LNA-safe fetch |
| `previewSeqRef` + meta poll | Local-first |
| `LOCAL_PHOTO_PREFIX` / `applyIncomingPhoto` | Optimistic + promote |
| `ingestWaiting` | Loading sau detect |
| `LatestCapturedSection` candidate chain | Sharpness + sticky |
| `ResolvePublicLiveView` / `booth_live_view` | Config webcam |
| `publishLocalPreview` / `preview_seq` multipart | Agent ↔ API |

---

*Generated for change `booth-hdmi-preview-porting-guide` (docs). Source of truth behavior: `booth-capture-preview-perf`.*
