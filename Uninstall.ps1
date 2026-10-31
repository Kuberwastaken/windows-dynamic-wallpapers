$ErrorActionPreference = 'Stop'
$task = Get-ScheduledTask -TaskName 'Windows Dynamic Wallpapers' -ErrorAction SilentlyContinue
if ($task) {
    Stop-ScheduledTask -TaskName $task.TaskName
    Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
}
$root = Join-Path $env:LOCALAPPDATA 'WindowsDynamicWallpapers'
if (Test-Path "$root\settings-backup.json") {
    $backup = Get-Content "$root\settings-backup.json" | ConvertFrom-Json
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    foreach ($name in @('RotatingLockScreenEnabled','RotatingLockScreenOverlayEnabled')) {
        if ($null -ne $backup.$name) { Set-ItemProperty $key $name $backup.$name }
        else { Remove-ItemProperty $key $name -ErrorAction SilentlyContinue }
    }
}
Write-Host 'Scheduled updates stopped. Choose your desktop and lock-screen backgrounds in Settings > Personalization.'
Write-Host "Images, converter, and backup are retained at $root; delete that folder when no wallpaper uses it."
