#Description: This resolves a specific cve (CVE-2023-24932) from Microsoft by updating the secure boot
#Assumption: The computer must be otherwise patched
#            You must have PSRemote ability to the machine

 Invoke-Command -ComputerName $hostname -ScriptBlock {
    mountvol q: /S
    if(!(Test-Path -Path "$env:systemroot\System32\SecureBootUpdates\SKUSiPolicy.P7b")){exit}
    xcopy $env:systemroot\System32\SecureBootUpdates\SKUSiPolicy.p7b q:\EFI\Microsoft\Boot
    mountvol q: /D
    Start-Sleep -Seconds 5
    reg add HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Secureboot /v AvailableUpdates /t REG_DWORD /d 0x10 /f
    Start-Sleep -Seconds 5
}

try {
    Restart-Computer -ComputerName "$hostname" -ErrorAction Stop -Force
} catch {
    Write-Warning "Unable to restart $hostname"
    continue
}

#Run five minutes later
Start-Sleep -Seconds 600
try {
    Restart-Computer -ComputerName "$hostname" -Force -ErrorAction Stop
} catch {
    Write-Warning "Unable to restart $hostname"
    continue
}

Invoke-Command -ComputerName $hostname -ScriptBlock {
    (Get-EventLog -LogName System -InstanceId 1035).Message
}
