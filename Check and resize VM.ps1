#Description: Resize vm on vsphere and in Disk Management via Windows 
#Assumption: You have already logged into vsphere with powershell

 function Resize-VM {
    param(
    [Parameter (Mandatory)][int] $NewSize,
    [Parameter (Mandatory)][string] $vmname
    )
    $vm = Get-VM -Name $vmname
    if($vm | Get-Snapshot){
        $vmname
    } else {
        $harddisk = get-harddisk -vm $vm
        try {
            $harddisk | set-harddisk -CapacityGB $NewSize -Confirm:$false | out-null
        } catch {
            $vmname
            break
        }
        Start-Sleep -seconds 10
        Invoke-Command -ComputerName $vmname -ArgumentList $vmname -ScriptBlock {
            param($vmname)
            $partition = (Get-Partition -DriveLetter C).size
            $size = (Get-PartitionSupportedSize -DriveLetter C).sizeMax
            try{
                Resize-Partition -DriveLetter C -Size $size
            } catch {
                break
            }
        }
    }
}
