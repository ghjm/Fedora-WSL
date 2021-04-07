Set WshShell = CreateObject("WScript.Shell")
Set args = WScript.Arguments.Named

Dim debug
debug = False
If args.Exists("debug") Then
    debug = true
End If

If debug Then
    Wscript.Echo "checking X server"
End If
' Check if X server loaded
RC = WshShell.Run("%comspec% /c netstat -a -n | find ""LISTENING"" | find "":6000""", 0, true)
If RC > 0 Then
    ' If not loaded, load it
    If debug Then
        Wscript.Echo "starting X server"
    End If
    WshShell.Run """C:\Program Files\Xming\Xming.exe"" :0 -clipboard -multiwindow"
End If

' Get IP address and gateway of WSL2 session
If debug Then
    Wscript.Echo "getting IP information"
End If
randomize
tmpf = WshShell.ExpandEnvironmentStrings("%TEMP%\") & (rnd*89999999 + 10000000) & ".tmp"
WshShell.Run "%comspec% /c wsl bash -c ""ip -4 route | grep default | cut -d ' ' -f 3; ip -4 addr show eth0 | grep inet | cut -d ' ' -f 6 | sed 's/\/.*//'"" > " & tmpf, 0, true
Set fso = CreateObject("Scripting.FileSystemObject")
Set file = fso.OpenTextFile(tmpf,1)
defroute = file.ReadLine()
ipaddr = file.ReadLine()
file.Close()
Set file = Nothing
fso.DeleteFile(tmpf)
Set fso = Nothing

' Authorize WSL to talk to our X server
If debug Then
    Wscript.Echo "authorizing X server"
End If
WshShell.Run "%comspec% /c set DISPLAY=127.0.0.1:0& ""C:\Program Files\Xming\xhost.exe"" +" & ipaddr, 0, true

' Run xlaunch or requested application
If args.Exists("command") Then
  command = args.Item("command")
Else
  command = "~/bin/xlunch"
End If
If debug Then
    Wscript.Echo "running command " & command
End If
WshShell.Run "%comspec% /c wsl DISPLAY=" & defroute & ":0 " & command, 0, false

Set WshShell = Nothing