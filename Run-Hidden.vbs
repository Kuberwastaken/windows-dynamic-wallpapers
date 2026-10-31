' Windows Script Host is a GUI process: no console is created for the launcher.
' Run PowerShell hidden from creation and propagate its exit status to Task Scheduler.
Option Explicit
Dim shell, files, folder, powershell, command, result
Set shell = CreateObject("WScript.Shell")
Set files = CreateObject("Scripting.FileSystemObject")
folder = files.GetParentFolderName(WScript.ScriptFullName)
powershell = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
command = Chr(34) & powershell & Chr(34) & " -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File " & Chr(34) & folder & "\Update.ps1" & Chr(34)
result = shell.Run(command, 0, True)
WScript.Quit result
