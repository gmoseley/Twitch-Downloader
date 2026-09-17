# Installs Twitch Downloader on a Windows machine: downloads the app,
# installs Python/ffmpeg/yt-dlp if missing, and registers a Scheduled Task
# so it starts automatically at boot and restarts itself if it crashes.
#
# Usage (run in an elevated PowerShell window):
#   irm https://raw.githubusercontent.com/gmoseley/Twitch-Downloader/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$RepoRawBase = "https://raw.githubusercontent.com/gmoseley/Twitch-Downloader/main"
$InstallDir  = Join-Path $env:LOCALAPPDATA "TwitchDownloader"
$DataDir     = Join-Path $InstallDir "data"
$TaskName    = "TwitchDownloader"

# Registering an AtStartup scheduled task needs admin rights -- re-launch
# elevated if this window isn't already one, rather than failing partway
# through the install.
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Re-launching as Administrator (needed to register the startup task)..."
    $selfPath = $MyInvocation.MyCommand.Path
    if ($selfPath) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$selfPath`""
    } else {
        # Running via `irm ... | iex`, so there's no local file to re-invoke.
        $cmd = "irm $RepoRawBase/install.ps1 | iex"
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
    }
    exit
}

function Test-Command($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

New-Item -ItemType Directory -Force -Path $InstallDir, $DataDir | Out-Null

Write-Host "==> Checking for Python..."
if (-not (Test-Command "python")) {
    Write-Host "Python not found -- installing via winget..."
    winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
    Write-Host "Python installed. If the next step fails to find it, close this window and re-run the installer in a fresh PowerShell so PATH picks it up."
}

Write-Host "==> Checking for ffmpeg..."
if (-not (Test-Command "ffmpeg")) {
    Write-Host "ffmpeg not found -- installing via winget..."
    winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
}

Write-Host "==> Installing/upgrading yt-dlp..."
python -m pip install --upgrade yt-dlp

Write-Host "==> Downloading the app..."
Invoke-WebRequest -Uri "$RepoRawBase/vod-downloader.py" -OutFile (Join-Path $InstallDir "vod-downloader.py")

Write-Host "==> Picking a free local port..."
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$Port = $listener.LocalEndpoint.Port
$listener.Stop()

Write-Host "==> Registering a Scheduled Task to run at startup..."
$pythonPath = (Get-Command python).Source
$scriptPath = Join-Path $InstallDir "vod-downloader.py"
$storageDir = Join-Path $DataDir "storage"
$stateDir   = Join-Path $DataDir "state"

# Scheduled Task actions don't take environment variables directly, so wrap
# the launch in cmd.exe to set them for just this process.
$envAndRun = "set VOD_STORAGE_ROOT=$storageDir&& set VOD_STATE_DIR=$stateDir&& set VOD_PORT=$Port&& set VOD_BIND_HOST=127.0.0.1&& `"$pythonPath`" `"$scriptPath`""
$action    = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c $envAndRun" -WorkingDirectory $InstallDir
$trigger   = New-ScheduledTaskTrigger -AtStartup
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $taskPrincipal -Settings $settings | Out-Null

Write-Host "==> Starting it now..."
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 2

$Url = "http://127.0.0.1:$Port/"
Write-Host ""
Write-Host "==> Twitch Downloader is running at: $Url"
Write-Host "    It's registered to start automatically every time this PC boots"
Write-Host "    (Task Scheduler > Task Scheduler Library > $TaskName), and to"
Write-Host "    restart itself if it ever crashes."
Write-Host ""
Write-Host "    Once the page opens, press Ctrl+D to bookmark it -- there's no"
Write-Host "    way for this script to do that for you (browsers dropped the"
Write-Host "    old API that let a page trigger the bookmark dialog)."
Write-Host ""
Start-Process $Url
