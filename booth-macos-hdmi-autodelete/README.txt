Selfbooth — kit booth macOS (HDMI + X Acquire + autodelete)
============================================================

Cung source agent voi kit Windows setup/booth-hdmi-xacquire-autodelete/.
Autodelete = AGENT_DELETE_AFTER_UPLOAD trong .env.agent.

Yeu cau
  - macOS (Apple Silicon hoac Intel)
  - Go 1.25+ (brew install go) — hoac copy san selfbooth-agent
  - Fujifilm X Acquire (ghi JPG vao WATCH_DIR)
  - Chrome kiosk tren cung may hoac may khac (ROOM_ID khop)

Build tren MacBook
  cd setup/booth-macos-hdmi-autodelete
  chmod +x *.sh
  ./build-agent.sh
  cp .env.agent.example .env.agent
  # Sua: API_BASE_URL, SERVICE_TOKEN, ROOM_ID, WATCH_DIR

Chay
  ./install-and-run.sh
  # hoac: ./run-agent.sh

Dung
  ./stop-agent-mac.sh

Kiem tra
  curl -s http://127.0.0.1:8791/status | head
  -> "delete_after_upload": true

WATCH_DIR macOS
  Thuong: /Users/<ten-ban>/Documents/FUJIFILM/XAcquire
  Tro vao thu muc CHA (X Acquire tu tao 582_FUJI, 583_FUJI...).

Autostart (tuy chon)
  launchd: ~/Library/LaunchAgents/com.selfbooth.hdmi-autodelete.plist
  ProgramArguments -> run-agent.sh, WorkingDirectory = folder kit.

Canh bao
  - KHONG chay kit nay va kit khac cung WATCH_DIR (kit nay XOA file sau upload).
  - Gatekeeper: xattr -dr com.apple.quarantine . trong folder kit.

Zip mang sang Mac (build tren Windows)
  Khong copy selfbooth-agent.exe. Tren Mac chay ./build-agent.sh.

Chi tiet hanh vi day du: setup/booth-hdmi-xacquire-autodelete/README.txt
