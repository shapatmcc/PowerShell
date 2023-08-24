#Description: This script updates virtual machines in vSphere from 2012 Server to 2016. It creates snapshots and runs the installer remotely
#Assumptions: You need the iso for the installer in one of the datastores. This script has two possibilities. 
#             You need the Check-KacePatching, Check-vSphereLogin, Update-KeyPermissions, and Start-KACEInventory files

param(
[Parameter (Mandatory)][string] $path
)

################
###Variables####
################
$DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$host.ui.rawui.windowtitle = (split-path -path $path -Leaf) -replace ".csv",""
$absolutePath = $myinvocation.MyCommand.path | Split-Path -Parent | split-Path -parent
$logPath = "$absolutePath\Logs\upgraded_to_2016_log.csv"
$vm = ""
$vmnames = (Import-Csv $Path -Delimiter ";" -Header 'vmname').vmname
$completedInstalls = @()
$upgradecount = $vmnames.count
$finaljobcount = @()

################
###Functions####
################
. $absolutePath\Scripts\Check-KacePatching.ps1
. $absolutePath\Scripts\Check-vSphereLogin.ps1
. $absolutePath\Scripts\Update-KeyPermissions.ps1
. $absolutePath\Scripts\Start-KACEInventory.ps1

################
###Pre-checks###
################
#Log into vsphere if not already
Check-vSphereLogin
clear
foreach($vmname in $vmnames){
    #check if patch detect file has been modified today
    Check-KacePatching -vmname $vmname
    
    #check if vm name exists
    try { $vm = Get-VM -name $vmname } catch { $vm = ""; Write-Host "Could not find $vmname. Exiting"; Read-Host; exit }

    #check if vm os is 2012
    if($vm.ExtensionData.Guest.GuestFullName -notlike "*2012*"){Write-Host "$vmname is not eligible for upgrade. Exiting"; Read-Host; exit}

    #check if previous upgrade snapshot exists
    if((get-snapshot $vm).name -like "*2012 Snapshot"){
        $snapshot = Get-Snapshot -VM $vm -Name "$vmname 2012 Snapshot"
        if($snapshot.created -lt (Get-Date -hour 0 -minute 0 -second 0)){
            Remove-Snapshot -Snapshot $snapshot -confirm:$false | out-null
            Start-Sleep -seconds 30
        }
    }
}


#########################
######Install Prep#######
#########################
foreach($vmname in $vmnames)
{
    #Create snapshot
    $vm = get-vm -name $vmname
    New-Snapshot -VM $vm -Name "$vmname 2012 Snapshot" | out-null
    Write-Host "Snapshot for $vmname made"

    #Determine ISO path based on datacenter of vm
    if((Get-Datacenter -vm $vm).Name -eq "DC1")
    {
       $datastoreName = "Content-Library-1"
       $isoPath = "[$datastoreName] ISO/S2016improvedudf.iso"
    } else {
        $datastoreName = "Content-Library-2"
        $isoPath = "[$datastoreName] S2016improvedudf.iso"
    }

    #Attach ISO
    Get-VM -Name $vmName | Get-CDDrive | Set-CDDrive -ISOPath $isoPath -Connected:$true -Confirm:$False | out-null
    Start-Sleep -Seconds 5

}
Write-Host ""

#########################
######Start Upgrade######
#########################
foreach($vmname in $vmnames){
    #Start job that runs the setup.exe on the machine, picking the standard with desktop experience, and ignoring compatibility warnings
    Start-Job -Name $vmname -ScriptBlock {
        param($targetHostname)
        try {
            Invoke-Command -ComputerName $targetHostname -ScriptBlock {
                $process = Start-Process "D:\setup.exe" -ArgumentList "/auto upgrade /imageIndex 2 /eula accept /compat IgnoreWarning /quiet" -Wait -PassThru
                $exitcode = $process.exitcode
                $exitcode
            } -ErrorAction Stop
        } catch {
            Write-Output "0110"
        }
    } -ArgumentList $vmname | out-null
    Write-Host "Running installer for $vmname"
}
Write-Host ""

#Waits for all the jobs to finish and pulls the exit code
while(Get-Job){
    $jobs = (Get-Job | ? {$_.state -eq "Completed"}).Name
    Start-Sleep -Seconds 30
    foreach($job in $jobs){
        $exitcode = Receive-Job -Name $job

        #if job is successful, it gets added to the completedInstalls array and the iso is removed
        if($exitcode -eq "0"){
            Write-Host "$job successfully started the upgrade"
            $completedInstalls += $job
            Remove-Job -Name $job
            Get-VM -Name $job | Get-CDDrive | Set-CDDrive -NoMedia -Confirm:$false | out-null
        }else{
            Write-Host "$job may not have installed correctly, exitcode: $exitcode"
            "$job, $(Get-Date), FAIL $exitcode" | Out-File $logpath -Append
            Remove-Job -Name $job
        }
    }
    Get-Job | Wait-Job -Any | out-null
}
Write-Host ""

#########################
#####Finish Upgrade######
#########################
Start-Sleep -seconds 600
foreach($completedInstall in $completedInstalls){
    #Start job that checks for a registry key that indicates the installation is complete
    Start-Job -Name $completedInstall -ScriptBlock {
        param($targetHostname,$absolutePath)
        $logpath = "$absolutePath\Logs\upgraded_to_2016_log.csv"
        
        #begins while loop that checks for the registry key value every 60 seconds
        $result = Invoke-Command -computername $targetHostname -ScriptBlock{Get-ItemPropertyValue -ErrorAction SilentlyContinue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State" -Name "ImageState"} -ErrorAction SilentlyContinue
        while($result -ne "IMAGE_STATE_COMPLETE"){
            Start-Sleep -Seconds 60
            $result = ""
            $result = Invoke-Command -computername $targetHostname -ScriptBlock{Get-ItemPropertyValue -ErrorAction SilentlyContinue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State" -Name "ImageState"} -ErrorAction SilentlyContinue
        }

        #checks the windows version once the install is complete, then updates the log file
        $windowsversion = invoke-command -computername $targetHostname -ScriptBlock {(get-computerinfo | select-object windowsproductname).windowsproductname}
        if($windowsversion -like "Windows Server 2016*"){
            "$targetHostname, $(Get-Date), Success" | Out-File $logpath -Append
            Write-Output "Success"
        }else{
            "$targetHostname, $(Get-Date), FAIL" | Out-File $logpath -Append
            Write-Output "Fail"
        }
    } -ArgumentList $completedInstall,$absolutePath | out-null
    Write-Host "Job started for $completedInstall to confirm upgrade"
}
Write-Host ""

#Grabs jobs as they finish and notes if they have been successfully upgraded or not
while(Get-Job){
    $jobs = (Get-Job | ? {$_.state -eq "Completed"}).Name
    $jobshtml = ""
    Start-Sleep -Seconds 30
    foreach($job in $jobs){
        $finalresult = Receive-Job -Name $job
        if($finalresult -eq "Success"){
            Write-Host "$job successfully upgraded... " -NoNewline
            Remove-Job -Name $job
            Start-Sleep -Seconds 5

            #Update Registry permissions
            Invoke-Command -computername $job -ScriptBlock ${function:Update-KeyPermissions}

            #Change netlogon service to start automatically
            Set-Service -ComputerName $job -Name Netlogon -StartupType Automatic
            Write-Host ""

            Invoke-Command -computername $job -scriptblock {
                $service = (get-childitem -path HKLM:\SYSTEM\CurrentControlSet\Services | ? {$_.Name -like "*bomgar*"}).Name
                $service = $service -replace "HKEY_LOCAL_MACHINE", "HKLM:"
                Set-ItemProperty -Path $service -Name DelayedAutoStart -Value 0
            }

            #Restart computer after a brief pause
            Start-Sleep -Seconds 20
            Restart-Computer -ComputerName $job -Force -Wait
            $jobshtml += "$job <br>"
            $finaljobcount += $job
        }elseif($finalresult -eq "Fail"){
            Write-Host "$job FAIL"
            Remove-Job -Name $job
        }else{
            Write-Host "$job had a result of '$finalresult'"
            Remove-Job -Name $job
        }
    }
    Get-Job | Wait-Job -Any | out-null
}

#Run the kbot to force inventory with KACE
foreach($finaljob in $finaljobcount){
    Start-Job -Name $finaljob -ScriptBlock {
        param($finaljob)
        Invoke-Command -computername $finaljob -ScriptBlock {Start-Process -FilePath "C:\Windows\System32\cmd.exe" -Verb runas -ArgumentList {/c "C:\Program Files (x86)\Quest\KACE\runkbot.exe" 4 0} -Wait}
    } -ArgumentList $finaljob | out-null
}

################
#####Cleanup####
################
$allsnapshots = Get-VM | Get-Snapshot | Where-Object { $_.Created -lt (Get-Date).AddDays(-3) } 
#Remove vmsnapshots older than 3 days
$allsnapshots | where-object { $_.name -like "* 2012 Snapshot"} | Remove-Snapshot -confirm:$false

Get-Job | Wait-Job
Disconnect-VIServer -confirm:$false
#Read-Host -Prompt "Done"
