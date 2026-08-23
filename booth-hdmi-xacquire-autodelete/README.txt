================================================================================
  booth-hdmi-xacquire-autodelete — kit Windows (HDMI live + X Acquire + autodelete)
================================================================================

Kit nay = ban sao booth-hdmi-xacquire, THEM 1 hanh vi:
  Sau khi API nhan anh (upload OK), agent XOA file JPG trong WATCH_DIR.

Kit goc finishAll\final\booth-hdmi-xacquire KHONG bi sua. Hai kit dung cung
selfbooth-agent.exe (cung source); khac biet nam o .env.agent.

Muc dich
  - Live view: HDMI capture card (kiosk webcam)
  - Anh chup: X Acquire ghi JPG -> agent watch folder -> local /preview (8791) -> upload -> XOA file
  - Trigger: Spacebar -> agent :8791 -> RR-100 relay (tuy chon)
  - Giu o dia booth PC khong bi phinh sau nhieu phien (JPG goc 3-8MB/shot)
  - Latest nhanh: sau ReadFile agent publish preview nhe (~1280px, q80) TRUOC khi nen upload
    (GET /preview/meta + /preview/latest.jpg); kiosk webcam poll :8791. Upload van di EDGE=3000.
  - AGENT_MAX_PHOTO_EDGE=3000 (mac dinh kit, chi anh huong upload/print). Dat 0 chi khi can archive original.
  - Session boundary: End / doi session → agent clear RAM /preview/latest.jpg (404) de khach sau
    khong thay still cu. Late X Acquire dump sau Start van ve sticky S1 (straggler hold);
    xem AGENT_STICKY_HANDOFF_SEC / AGENT_SESSION_STRAGGLER_SEC trong .env.agent.
  - AGENT_MAX_PHOTO_BYTES=3145728 (3 MiB cap) neu co trong .env.agent.

CANH BAO
  - KHONG chay kit nay va kit goc song song tren cung WATCH_DIR
    (kit nay se xoa file truoc khi kit kia upload).
  - Xoa la khong hoi phuc. Chi bat khi da tin cay duong upload
    (chay RELAY_MODE=none + chup thu, xem log DELETED truoc khi dung that).
  - Anh tren the SD / trong may Fujifilm KHONG bi xoa (chi file da drop vao WATCH_DIR).

Xoa khi nao (chinh xac)
  XOA:     upload tra OK lan dau (log "UPLOADED:")  -> "DELETED: <file> (<n> bytes)"
           upload tra OK o retry  (log "UPLOADED (retry N):") -> "DELETED: ..."
  GIU:     NO SESSION (kiosk chua Start)
           stable_wait_failed (file chua on dinh)
           upload fail het retry -> spool cho retry sau
           xoa loi (file dang bi giu handle) -> "DELETE FAILED: <file>: <err>"
  Loi xoa KHONG lam fail upload; kiosk khong hien banner loi vi viec nay.

Buoc chay
  1. Build exe:  .\build-agent.ps1        (chay test + go build vao folder nay)
     Hoac copy selfbooth-agent.exe (ban moi) vao folder nay.
  2. Copy .env.agent.example -> .env.agent, sua API_BASE_URL / SERVICE_TOKEN /
     ROOM_ID / WATCH_DIR.
  3. Bat X Acquire (folder: Documents\FUJIFILM\XAcquire\102_FUJI\582_FUJI)
  4. Double-click run-agent.cmd  (banner in ra AGENT_DELETE_AFTER_UPLOAD=...)
  5. Kiosk: live_view_mode=webcam, dung ROOM_ID
  6. Space de test -> xem log "UPLOADED" roi "DELETED"

Log
  - AGENT_LOG_FILE=logs\agent.log (mac dinh trong .env.agent.example).
    Duong dan tuong doi duoc quy ve folder kit nay; run-agent.ps1 tu tao logs\.
  - PHAI chay qua run-agent.cmd / run-agent.ps1: agent doc AGENT_LOG_FILE tu
    process env luc khoi tao logger (truoc khi doc .env.agent), nen chay
    selfbooth-agent.exe -env ... truc tiep se CHI log ra console.
  - Rotation: AGENT_LOG_MAX_BYTES=5242880 (5MB), AGENT_LOG_KEEP=3
    -> logs\agent.log, agent.log.1 .. agent.log.3
  - Log ra CA console va file.
  - AGENT_DEBUG=true de xem chi tiet detect/skip/latency (mac dinh tat).

Kiem chung nhanh
  curl http://127.0.0.1:8791/status
    -> "delete_after_upload": true
    -> "last_delete": "ok: DSCF0001.JPG"   (hoac "fail: ...")
    -> "skipped_uploaded" / "skipped_refused" / "skipped_backlog": phai la 0
       trong mot phien chup binh thuong
    -> "last_skip_reason": ly do bo anh gan nhat (null neu chua bo anh nao)

Chan doan theo chu ky log
  Moi anh bi bo deu co mot dong "SKIP <ly do>: <file>" — khong con im lang.

  "DETECTED: <file>" roi IM LANG, khong co UPLOADED / NO SESSION / SKIP
    -> ban agent cu (truoc ban va cham fix-agent-ingest-photo-drop). Nang cap exe.

  "SKIP already_uploaded" cho anh vua chup xong
    -> store nho nham; chay stop-agent.cmd roi reset-processed.cmd roi run-agent.cmd.

  "SKIP backlog" cho anh vua chup xong
    -> dong ho may anh lech nhieu gio VA agent chua duoc nang cap, hoac
       AGENT_BACKLOG_MAX_AGE_SEC dat qua thap.

  "NO SESSION — ignoring upload"
    -> kiosk chua bam Start. Anh bi tu choi cho tien trinh nay, nhung quyet dinh
       do KHONG luu xuong dia: restart agent thi anh do duoc xet lai.

  "BIND RETRY" roi "BIND GIVE UP"
    -> backend/mang khong tra loi duoc trong AGENT_BIND_RETRY_MS. Kiem tra
       API_BASE_URL va duong mang truoc khi do loi cho agent.

  Xuat hien file hau to "(1)" trong WATCH_DIR (DSCF0939(1).JPG)
    -> may anh da quay vong bo dem frame va X Acquire dang tranh de len ten cu.
       Ban agent moi van nhan dung ca hai; neu ban cu thi day la dau hieu
       ro nhat cua loi bo anh im lang.

Tat autodelete (rollback)
  - Sua .env.agent: AGENT_DELETE_AFTER_UPLOAD=false  (hoac xoa dong do)
  - Restart agent (stop-agent.cmd roi run-agent.cmd)
  - Khong can build lai. Agent quay ve hanh vi y het kit goc.

Tu dong chay
  - Double-click install-startup-task.cmd mot lan sau khi giai nen.
  - Task name rieng: "Selfbooth HDMI XAcquire Agent (autodelete)" — khong ghi de
    task cua kit goc. Neu truoc do da cai task kit goc, HAY go no
    (uninstall-startup-task.cmd trong kit goc) de tranh 2 agent cung WATCH_DIR.
  - Go cai bang uninstall-startup-task.cmd.

Phan con lai (WATCH_DIR drift, RELAY_MODE, config parity, kiosk banner, ZIP,
lockdown ADR-004, /health /status /trigger) GIONG kit goc — doc:
  finishAll\final\booth-hdmi-xacquire\README.txt
  finishAll\final\booth-hdmi-xacquire\HDMI-XACQUIRE-CHECKLIST.md

File
  .env.agent.example         — mau (da bat AGENT_DELETE_AFTER_UPLOAD=true + log file)
  build-agent.ps1            — test + build selfbooth-agent.exe vao folder nay
  run-agent.cmd / .ps1       — chay agent (in ra trang thai delete knob + log path)
  install-startup-task.*     — cai tu dong chay logon + unlock (task name rieng)
  uninstall-startup-task.*   — go scheduled task
  stop-agent.cmd / .ps1      — dung agent
  reset-processed.cmd / .ps1 — xoa store "da upload" khi agent bo anh nham
  AUTODELETE-NOTES.md        — khac biet vs kit goc + checklist verify
  ENV-CUSTOMIZATION.md       — custom nhieu site chi qua .env.agent (chat luong anh, preset)
================================================================================
