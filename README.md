# Twitch Downloader

My girlfriend has a messy way of keeping track of her clips, and it meant
she kept ending up editing with low quality re-downloads instead of the
real thing. I built this with Claude Code to keep her VODs and clips
somewhere she could actually find them. It worked out well enough that I
cleaned it up so you can run it on your own Linux server or Windows desktop
too. Hopefully it works as well for you as it has for us.

## What it does

A single-file web app that watches Twitch channels and downloads their VODs
and clips (via `yt-dlp`) before Twitch's own retention window deletes them.
There's also a paste-a-link/search tab for one-off Twitch or YouTube links.

Everything is managed from the "Manage Channels" tab: which channels get
tracked, how often each one gets checked, how far back to look, and where
files land. No redeploy needed to add or remove a channel. There's no
database either, just a `jobs.json` file next to the process, plus
`channels.json` and `config.json` for the tracked-channel list and storage
root.

Each tracked channel gets its own tab with VODs, Clips, and Deleted
sub-tabs. Downloads land under `<storage root>/<channel>/VODs` and
`<storage root>/<channel>/Clips`. One-off paste-a-link/search downloads land
under `<storage root>/Manual Downloads` and auto-purge after 7 days.

It also has a global download speed limit, Pause All/Resume All (a
freshly-added channel starts paused by default so it doesn't immediately
saturate your connection with months of backlog), pagination on the long
tables, and locally cached thumbnails so a VOD or clip Twitch has since
deleted doesn't leave a broken image or a dead link.

The whole thing is LAN-only: gated by private IP, or just localhost on a
single-machine install. There's no login and no public access mode, so
don't put it on the open internet.

## Running it

Pick whichever fits:

### Docker

```
git clone https://github.com/gmoseley/Twitch-Downloader.git
cd Twitch-Downloader
docker compose up -d
```

The web UI is then at `http://localhost:8787/`. Downloaded files and app
state land in `./data` next to the compose file.

### Linux (systemd service)

```
curl -fsSL https://raw.githubusercontent.com/gmoseley/Twitch-Downloader/main/install.sh | sudo bash
```

Installs git, python3, ffmpeg, and yt-dlp if you don't already have them,
clones the app to `/opt/twitch-downloader`, and sets it up as a systemd
service (`twitch-downloader`) that comes back up on reboot. To update later:

```
cd /opt/twitch-downloader && git pull && systemctl restart twitch-downloader
```

### Windows (single machine)

In an elevated PowerShell window:

```
irm https://raw.githubusercontent.com/gmoseley/Twitch-Downloader/main/install.ps1 | iex
```

Installs Python, ffmpeg, and yt-dlp via `winget` if missing, downloads the
app to `%LOCALAPPDATA%\TwitchDownloader`, binds it to `127.0.0.1` on a
random free port, and registers a Scheduled Task so it starts at boot and
restarts itself if it crashes. It'll open the page in your browser when
done. Press `Ctrl+D` to bookmark it.

### Manual / from source

Requires `yt-dlp` and `ffmpeg`/`ffprobe` on `PATH`. Configure it with
environment variables, then run:

```
VOD_STORAGE_ROOT=/path/to/storage \
VOD_STATE_DIR=/path/to/state \
python3 vod-downloader.py
```

| Variable | Purpose | Default |
|---|---|---|
| `VOD_STORAGE_ROOT` | Initial storage root (per-channel `VODs`/`Clips` folders and `Manual Downloads` are created under this). Editable afterward from the Manage Channels tab, which saves the change to `config.json` | `/srv/share/VOD Downloader` |
| `VOD_STATE_DIR` | Job state, tracked-channel list, storage-root/speed-limit config, and caches | `/var/lib/vod-downloader` |
| `VOD_PORT` | Port the web UI listens on | `8787` |
| `VOD_BIND_HOST` | Interface to bind to. Use `127.0.0.1` for a single-machine/localhost-only install, or `0.0.0.0` to be reachable from the rest of your LAN | `0.0.0.0` |
| `VOD_YTDLP_PATH` | Path to the `yt-dlp` executable, if it's not on `PATH` | `yt-dlp` |

Tracked channels (username, "check every N hours", and "keep last N days")
get added, edited, and removed from the Manage Channels tab. There's no env
var for that, since it's meant to change without a redeploy.

## Deploying as a systemd service manually

`vod-downloader.service` is a template unit. Fill in the `Environment=`
lines for your deployment, drop it in `/etc/systemd/system/`, then:

```
systemctl daemon-reload
systemctl enable --now vod-downloader
```

(`install.sh` does this part for you automatically.)
