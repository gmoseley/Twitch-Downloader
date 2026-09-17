#!/usr/bin/env bash
# Installs Twitch Downloader as a systemd service on a Linux server.
# Usage: curl -fsSL https://raw.githubusercontent.com/gmoseley/Twitch-Downloader/main/install.sh | sudo bash
#
# Every setting below can be overridden via environment variables, e.g. to
# run a second, separate instance on the same box:
#   SERVICE_NAME=my-test PORT=8788 STORAGE_DIR=/srv/share/my-test \
#     curl -fsSL <url>/install.sh | sudo -E bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/gmoseley/Twitch-Downloader.git}"
SERVICE_NAME="${SERVICE_NAME:-twitch-downloader}"
INSTALL_DIR="${INSTALL_DIR:-/opt/${SERVICE_NAME}}"
STATE_DIR="${STATE_DIR:-/var/lib/${SERVICE_NAME}}"
STORAGE_DIR="${STORAGE_DIR:-/srv/twitch-downloader}"
PORT="${PORT:-8787}"

if [ "$(id -u)" -ne 0 ]; then
  echo "This installer needs root (it installs packages and a systemd service)." >&2
  echo "Try: curl -fsSL <url> | sudo bash" >&2
  exit 1
fi

echo "==> Detecting package manager..."
if command -v apt-get >/dev/null 2>&1; then
  INSTALL_PKGS="apt-get update -qq && apt-get install -y git python3 python3-pip ffmpeg"
elif command -v dnf >/dev/null 2>&1; then
  INSTALL_PKGS="dnf install -y git python3 python3-pip ffmpeg"
elif command -v yum >/dev/null 2>&1; then
  INSTALL_PKGS="yum install -y git python3 python3-pip ffmpeg"
elif command -v pacman >/dev/null 2>&1; then
  INSTALL_PKGS="pacman -Sy --noconfirm git python python-pip ffmpeg"
else
  echo "Could not detect apt/dnf/yum/pacman. Install git, python3, pip, and ffmpeg manually, then re-run this script." >&2
  exit 1
fi

echo "==> Installing git, python3, pip, ffmpeg..."
eval "$INSTALL_PKGS"

echo "==> Installing/upgrading yt-dlp..."
python3 -m pip install --upgrade --break-system-packages yt-dlp 2>/dev/null \
  || python3 -m pip install --upgrade yt-dlp

echo "==> Fetching the app..."
if [ -d "$INSTALL_DIR/.git" ]; then
  git -C "$INSTALL_DIR" pull --ff-only
else
  git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

mkdir -p "$STATE_DIR" "$STORAGE_DIR"

echo "==> Installing the systemd service..."
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<UNIT
[Unit]
Description=Twitch VOD/clip download manager (web panel + downloader)
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=$(command -v python3) ${INSTALL_DIR}/vod-downloader.py
Restart=always
RestartSec=5
Environment="VOD_STORAGE_ROOT=${STORAGE_DIR}"
Environment="VOD_STATE_DIR=${STATE_DIR}"
Environment="VOD_PORT=${PORT}"

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}"

IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
echo ""
echo "==> Done. The web panel is at:"
echo "      http://localhost:${PORT}/"
if [ -n "$IP" ]; then
  echo "      http://${IP}:${PORT}/  (from other devices on your LAN)"
fi
echo ""
echo "By design it only responds to requests from private/LAN IP addresses --"
echo "there is no login, so keep it off the open internet."
echo ""
echo "To update later:  cd ${INSTALL_DIR} && git pull && systemctl restart ${SERVICE_NAME}"
