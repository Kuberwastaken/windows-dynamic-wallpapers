param(
    [Parameter(Mandatory=$true)][string]$HeicPath,
    [string]$SchedulePath,
    [switch]$RestartExplorer
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run setup with Windows PowerShell 5.1 (powershell.exe).' }
$source = (Resolve-Path -LiteralPath $HeicPath).Path
$root = Join-Path $env:LOCALAPPDATA 'WindowsDynamicWallpapers'
$taskName = 'Windows Dynamic Wallpapers'
New-Item -ItemType Directory -Force $root | Out-Null
# Isolate conversion dependencies from the user's Python packages.
$venv = Join-Path $root 'converter'
if (!(Test-Path "$venv\Scripts\python.exe")) {
    python -m venv $venv
    if ($LASTEXITCODE) { throw 'Python 3.10+ is required; install Python and ensure python is on PATH.' }
}
& "$venv\Scripts\python.exe" -m pip install -r "$PSScriptRoot\requirements.txt" --disable-pip-version-check
if ($LASTEXITCODE) { throw 'Could not install HEIC conversion dependencies.' }
# Validate and convert before replacing an existing installation.
$staging = Join-Path $root ('staging-' + [guid]::NewGuid().ToString('N'))
$arguments = @("$PSScriptRoot\convert_heic.py", $source, $staging)
if ($SchedulePath) { $arguments += @('--schedule', (Resolve-Path -LiteralPath $SchedulePath).Path) }
& "$venv\Scripts\python.exe" @arguments
if ($LASTEXITCODE) { throw 'HEIC conversion failed; existing configuration was not replaced.' }
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) { Stop-ScheduledTask -TaskName $taskName }
if (!(Test-Path "$root\settings-backup.json")) {
    $desktop = Get-ItemProperty 'HKCU:\Control Panel\Desktop'
    $content = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -ErrorAction SilentlyContinue
    @{ Wallpaper=$desktop.Wallpaper; WallpaperStyle=$desktop.WallpaperStyle; TileWallpaper=$desktop.TileWallpaper;
       RotatingLockScreenEnabled=$content.RotatingLockScreenEnabled;
       RotatingLockScreenOverlayEnabled=$content.RotatingLockScreenOverlayEnabled } | ConvertTo-Json | Set-Content "$root\settings-backup.json"
}
Copy-Item "$staging\*" $root -Force
Copy-Item "$PSScriptRoot\Update-Wallpaper.ps1" "$root\Update.ps1" -Force
Copy-Item "$PSScriptRoot\Run-Hidden.vbs" "$root\Run-Hidden.vbs" -Force
Remove-Item "$root\success.txt" -ErrorAction SilentlyContinue
$contentKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
New-Item $contentKey -Force | Out-Null
Set-ItemProperty $contentKey RotatingLockScreenEnabled 0
Set-ItemProperty $contentKey RotatingLockScreenOverlayEnabled 0
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\wscript.exe" -Argument "//B //NoLogo `"$root\Run-Hidden.vbs`""
$triggers = @(New-ScheduledTaskTrigger -AtLogOn -User $user)
foreach ($entry in (Get-Content "$root\schedule.json" | ConvertFrom-Json)) {
    $triggers += New-ScheduledTaskTrigger -Daily -At ([datetime]::Today.AddSeconds([math]::Round($entry.t * 86400)))
}
$triggers += New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Minutes 5)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Settings $settings -User $user -RunLevel Limited -Force | Out-Null
# Wake events vary by hardware; the periodic trigger provides a fallback.
[xml]$xml = Export-ScheduledTask -TaskName $taskName
$ns = $xml.DocumentElement.NamespaceURI
$event = $xml.CreateElement('EventTrigger', $ns)
$enabled = $xml.CreateElement('Enabled', $ns); $enabled.InnerText = 'true'; [void]$event.AppendChild($enabled)
$subscription = $xml.CreateElement('Subscription', $ns)
$subscription.InnerText = '<QueryList><Query Id="0" Path="System"><Select Path="System">*[System[Provider[@Name="Microsoft-Windows-Power-Troubleshooter"] and EventID=1]]</Select></Query></QueryList>'
[void]$event.AppendChild($subscription); [void]$xml.Task.Triggers.AppendChild($event)
try { Register-ScheduledTask -TaskName $taskName -Xml $xml.OuterXml -Force | Out-Null }
catch { Write-Warning "Wake trigger unavailable; five-minute recovery remains enabled. $_" }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$root\Update.ps1"
if ($LASTEXITCODE) { throw "Wallpaper update failed. Read $root\error.txt" }
if ($RestartExplorer) { Stop-Process -Name explorer -Force; Start-Process explorer.exe }
Write-Host "Installed. Disable other wallpaper apps and their startup entries to avoid conflicts."
Write-Host "Files: $root | Task: $taskName"
