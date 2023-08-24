#Description: This changes the bomgar service to automatic and removes the delayedstart portion
Invoke-Command -computername $hostname -scriptblock {
    $service = (get-childitem -path HKLM:\SYSTEM\CurrentControlSet\Services | ? {$_.Name -like "*bomgar*"}).Name
    $service = $service -replace "HKEY_LOCAL_MACHINE", "HKLM:"
    Write-host $service
    Set-ItemProperty -Path $service -Name DelayedAutoStart -Value 0
    Start-Sleep -Seconds 5
    Start-Service -DisplayName *BeyondTrust* 
}
