#Description: This script checks the files on the local computer to see if it has been patched or is being patched by KACE today. This can be useful if you want to avoid doing work on a machine that is already undergoing maintenance. 
 
 function Check-KacePatching {
    param(
    [Parameter(Mandatory)]
    $vmname)
    try {
    Invoke-Command -computername $vmname -ScriptBlock {
        param($vmname)

        if((Get-Date -Date $((Get-Item -Path "C:\ProgramData\Quest\KACE\kpd\KPATCH_DETECT_OUTPUT.txt").LastWriteTime) -Format yyyyMMdd) -eq (Get-Date -Format yyyyMMdd)){
            Read-Host -Prompt "$vmname might be being patched"
        }
    } -ArgumentList $vmname -ErrorAction Stop
    } catch {
        Read-Host "$Failed to reach vmname "
    }
}
