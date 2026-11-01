$ErrorActionPreference='Stop'
try {
$r=$PSScriptRoot
$s=Get-Content "$r\schedule.json" | ConvertFrom-Json
$c=$s | Where-Object {$_.t -le ((Get-Date).TimeOfDay.TotalDays+0.000001)} | Select-Object -Last 1
if (!$c) {$c=$s[-1]}
$p=Join-Path $r ($c.i.ToString()+'.jpg')
$source=$p
$p=Join-Path $r 'Current.jpg'
$desktopKeys=@(Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops\Desktops' -ErrorAction SilentlyContinue)
$needsDesktopSync=@($desktopKeys | Where-Object {(Get-ItemProperty $_.PSPath).Wallpaper -ne $p}).Count -gt 0
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime] | Out-Null
$lockMatches = [Windows.System.UserProfile.LockScreen]::OriginalImageFile.LocalPath -eq $source
if ($lockMatches -and !$needsDesktopSync -and (Get-ItemProperty 'HKCU:\Control Panel\Desktop').Wallpaper -eq $p -and (Test-Path "$r\success.txt") -and (Get-Content "$r\success.txt") -eq $source) {exit}
Copy-Item -LiteralPath $source -Destination $p -Force
Add-Type 'using System.Runtime.InteropServices; public class WP { [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern bool SystemParametersInfo(int a,int b,string c,int d); }'
Set-ItemProperty 'HKCU:\Control Panel\Desktop' WallpaperStyle '10'
Set-ItemProperty 'HKCU:\Control Panel\Desktop' TileWallpaper '0'
if (![WP]::SystemParametersInfo(20,0,$p,3)) {throw 'Desktop failed'}
Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops\Desktops' -ErrorAction SilentlyContinue | ForEach-Object {Set-ItemProperty $_.PSPath Wallpaper $p}
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' BackgroundType 0
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; [ComImport, Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] public interface IWallpaper { void SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitor,[MarshalAs(UnmanagedType.LPWStr)] string path); } public class DesktopWP { public static void Set(string path) { var o=Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD"))); try { ((IWallpaper)o).SetWallpaper(null,path); } finally { Marshal.ReleaseComObject(o); } } }'
[DesktopWP]::Set($p)
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
[Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime] | Out-Null
$m=([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'})[0]
$t=$m.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null,@([Windows.Storage.StorageFile]::GetFileFromPathAsync($source)))
$t.Wait()
$am=([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {$_.Name -eq 'AsTask' -and !$_.IsGenericMethod -and $_.GetParameters().Count -eq 1})[0]; $at=$am.Invoke($null,@([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($t.Result))); $at.Wait()
$source | Set-Content "$r\success.txt"
Remove-Item "$r\error.txt" -ErrorAction SilentlyContinue
} catch { $_ | Out-String | Set-Content "$PSScriptRoot\error.txt"; exit 1 }
