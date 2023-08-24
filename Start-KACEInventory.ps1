function Start-KACEInventory {
    Start-Process -FilePath "C:\Windows\System32\cmd.exe" -Verb runas -ArgumentList {/c "C:\Program Files (x86)\Quest\KACE\runkbot.exe" 4 0} -Wait
}