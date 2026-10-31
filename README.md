# Windows Dynamic Wallpapers

Use a **dynamic HEIC / HEIF wallpaper on Windows**, with time-based updates for both the desktop background and lock screen. Extract a macOS-style HEIC wallpaper once, then let Windows Task Scheduler select the right still image throughout the day.

No resident wallpaper app, video rendering, location service, or subscription. A short PowerShell process runs at scheduled times, login, wake, and every five minutes as a recovery check. This is designed for low overhead; resource use has not been benchmarked across devices.

## Setup

Requires Windows 11 (the target platform), Windows PowerShell 5.1, and **Python 3.10+** available as `python`. Windows 10 may work but is untested. Setup needs internet access for Python dependencies; normal wallpaper updates work offline. No administrator privileges are normally required; managed PCs may restrict Task Scheduler or lock-screen changes.

1. Download or clone this repository.
2. Stop any other wallpaper changer and disable its startup entry. Choose **Picture** instead of Windows Spotlight or Slideshow in **Settings > Personalization > Lock screen**. Setup also disables the per-user rotating lock-screen settings, but Windows versions and policies can affect them.
3. Open Windows PowerShell in this folder and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Setup.ps1 -HeicPath "C:\Wallpapers\My Dynamic Wallpaper.heic"
```

Keep your original HEIC or HEIF wherever you like. Setup reads it without moving or modifying it. Python packages are installed in a dedicated virtual environment, not your global Python installation. No wallpaper images are included in this repository; bring an image you have permission to use.

If switching virtual desktops briefly restores an old wallpaper, save any File Explorer work and rerun with `-RestartExplorer`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Setup.ps1 -HeicPath "C:\Wallpapers\My Dynamic Wallpaper.heic" -RestartExplorer
```

That option briefly restarts the taskbar and desktop shell and can close File Explorer windows. It does not restart Windows. Setup applies one shared background to all existing virtual desktops, replacing separate per-desktop choices.

## Supported HEIC / HEIF types

| Wallpaper type | Support |
| --- | --- |
| Multi-image HEIC / HEIF with Apple `h24` time-of-day XMP metadata | Automatic frame extraction and original time schedule |
| Solar-position dynamic HEIC (`solar` metadata) | Supply a custom time schedule; no sunrise/sunset calculation |
| HEIC / HEIF with missing or unfamiliar dynamic metadata | Supply a custom time schedule |
| Single-image HEIC / HEIF photo | Custom schedule works, but a single frame stays static |
| JPG, PNG, GIF, video, Live Photos, `.ddw` | Not supported as setup inputs |

The `.heic` extension alone does not mean an image contains multiple frames or a dynamic schedule. HEIC/HEIF frames are decoded by [pillow-heif](https://github.com/bigcat88/pillow_heif) and converted to JPEG. HDR and wide-gamut color fidelity are not guaranteed by this conversion pipeline.

For a custom HEIC wallpaper schedule, create a JSON file:

```json
[
  { "i": 0, "t": 0.2916666666666667 },
  { "i": 1, "t": 0.5 },
  { "i": 2, "t": 0.75 }
]
```

`i` is the zero-based HEIC frame index; `t` is the fraction of a local day: 7 AM = `7/24`, noon = `0.5`, 6 PM = `0.75`. Before the first daily change, the last frame from the previous day's schedule remains selected. Times follow the computer's local clock, not the sun's position.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Setup.ps1 -HeicPath "C:\Wallpapers\theme.heif" -SchedulePath .\my-schedule.json
```

## How it works

- Extracts the HEIC / HEIF image sequence and validates its time metadata before installation.
- Stores JPEG frames, a schedule, logs, and the updater under `%LOCALAPPDATA%\WindowsDynamicWallpapers`.
- Registers the current-user **Windows Dynamic Wallpapers** scheduled task. It runs only in your interactive user session, including on battery, and does not wake the laptop to change a picture.
- Updates a stable `Current.jpg` file shared by virtual desktops, uses Windows desktop wallpaper APIs, and sets the lock-screen image through WinRT.
- Checks every five minutes as a fallback for missed events or another setting overriding the desktop. When the selected image is already applied, it exits early.

The virtual-desktop registry workaround is Windows-version dependent. Explorer may need one restart to discard old per-desktop caches. This is a small community script, not a guarantee against Windows updates, personalization changes, third-party wallpaper apps, or organization policy.

**No animated crossfade:** this changes still images. It does not reproduce the macOS smooth wake transition, live wallpaper, or screensaver animation. Lock-screen updates may only appear on the next lock; the pre-login system background is outside this per-user setup.

## Troubleshooting

If the old wallpaper reappears, first stop other background changers, Windows slideshows, and automatic theme changes. Check the task and most recent error:

```powershell
Get-ScheduledTaskInfo -TaskName 'Windows Dynamic Wallpapers'
Get-Content "$env:LOCALAPPDATA\WindowsDynamicWallpapers\error.txt"
Start-ScheduledTask -TaskName 'Windows Dynamic Wallpapers'
```

`LastTaskResult` of `0` means the last task completed successfully. `success.txt` records the last applied frame. Check desktop switching, a timed change, sleep/resume, and login on your own hardware. A successful API call does not guarantee Windows will display the lock-screen image under every policy.

To switch HEIC wallpaper packs, rerun setup with a different file. To stop scheduled updates:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

Uninstall restores the saved rotating lock-screen flags and retains images and backups. Choose a new desktop and lock-screen picture in Settings afterward. It does not automatically restore previous per-virtual-desktop backgrounds or re-enable third-party wallpaper apps.

## Development

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m unittest discover -s tests
```

Search terms: Windows dynamic wallpaper, HEIC wallpaper Windows 11, HEIF wallpaper, macOS dynamic desktop for Windows, time-of-day wallpaper, scheduled desktop background, dynamic lock screen, multi-image HEIC, Apple h24 metadata.

MIT licensed. HEIC wallpaper artwork remains the property of its respective creators.
