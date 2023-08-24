#Description: This takes a csv and checks the computers listed to update their Autologon if not enabled or has the wrong user
#Assumptions: You need PSRemote ability to the machines
#             The csv has the username (which matches the computername except for "svc" at the beginning), and the password
 
 ##Computer running this needs to have the AD module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Warning "This machine requires the ActiveDirectory module to continue"
    break
}

#Generate file picker
[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
$OpenFIleDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.InitialDirectory = $InitialDirectory
$OpenFileDialog.Filter = "CSV (*.csv) | *.csv"
$OpenFileDialog.ShowDialog() | Out-Null
$Path = $OpenFileDialog.Filename

################
###Variables####
################
$RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$UserNameKey = "DefaultUserName"
$PasswordKey = "DefaultPassword"
$DomainKey = "DefaultDomain"
$AutoLogonServerPath = "\\networkshare\Autologon\Autologon.exe"
$AutoLogonLocalPath = "C:\Autologon\Autologon.exe"
$domain = "domain"
$domainname = "domain.com"
$oldusername = "oldusername"
$accessGroup = ""
$potentialNetworkPaths = $false
# Store the data from CSV file in the $ADUsers variable
$computers = Import-Csv $Path -Delimiter ";" -Header 'username','password'

foreach($computer in $computers)
{
    #Declare variables in loop
    ###Change this line below before production
    $hostname = $computer.username.ToLower()
    if($hostname -like "svc*")
    {
        $hostname = $hostname.Substring(3)
    }
    $username = $computer.username.ToLower()
    $password = $computer.password

    #if ip address in earlier array is found, it skips and goes to the next entry in the loop
    if($potentialdecoms -contains $hostname)
    {
        continue
    }

    #Make sure the hostname can be reached
    try {
        $ip = (Resolve-DnsName -Name $hostname -ErrorAction Stop).IPAddress
    } catch {
        Write-Warning "Unable to find IP address for $hostname"
        continue
    }

    #test username credentials before applying them to the computer
    ##comment out during testing
    if((New-Object DirectoryServices.DirectoryEntry "",$username,$password).psbase.name -eq $null) {
        Write-Warning "Credentials not valid for username $username"
        continue
    }

    #Test the ability to psremote
    try {
        Test-WSMan -ComputerName "$hostname.domainname -ErrorAction Stop| out-null
    } catch {
        Write-Warning "Remote connection not established for $hostname"
        continue
    }

    #checks for the autologon.exe and adds it to the C:\AutoLogon folder if not already there
    if(!(Invoke-Command -ComputerName $hostname -ScriptBlock{param($AutoLogonLocalPath) Test-Path $AutoLogonLocalPath} -ArgumentList $AutoLogonLocalPath))
    {
        try {
            Copy-Item -Path "$AutoLogonServerPath" -Destination "\\$hostname.$domainname\c$\Autologon\Autologon.exe"
            Write-Host "Copied Autologon.exe file to $hostname"
        } catch {
            Write-Warning "Unable to copy autologon.exe to $hostname"
            continue
        }
    }

    #Begin remoting in and carry over all the variables needed
    Invoke-Command -ComputerName "$hostname.domain" -ArgumentList $username,$password,$UserNameKey,$PasswordKey,$RegistryPath,$hostname,$AutoLogonLocalPath,$DomainKey,$domain,$potentialNetworkPaths -ScriptBlock {
        param($username,$password,$UserNameKey,$PasswordKey,$RegistryPath,$hostname,$AutoLogonLocalPath,$DomainKey,$domain,$potentialNetworkPaths)
        #Test the connection to the domain
        try {
            Test-ComputerSecureChannel -Server $domainname | Out-Null
        } catch {
            Write-Warning "Could not establish valid connection from $hostname to domain"
            return
        }
        #Checks for the defaultusername key in the registry
        try {
            $registryusername = (Get-ItemProperty -Path $RegistryPath -Name $UserNameKey -ErrorAction Stop).DefaultUserName
        } catch {
            Write-Warning "Registry key for $UserNameKey not found for $hostname"
        }
        #
        if($registryusername -ne $username)
        {
            foreach($potentialPath in $PotentialNetworkPaths)
            {
                $ACL = ""
                if(Test-Path -Path $potentialPath)
                {
                    $ACL = Get-ACL -Path $potentialPath
                    Write-Host "Found path $potentialPath . Adding permissions"

                }
                if($ACL <#-and ($ACL.Access.IdentityReference.Value -notcontains $accessGroup)#>)
                {
                    $AccessRights = [System.Security.AccessControl.FileSystemRights]::FullControl
                    $InheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit, [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
                    $PropogationFlags = [System.Security.AccessControl.PropagationFlags]::None
                    $AccessControlType = [System.Security.AccessControl.AccessControlType]::Allow

                    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule ($accessGroup,$AccessRights, $InheritanceFlags, $PropogationFlags, $AccessControlType)
                    $ACL.SetAccessRule($AccessRule)
                    $ACL | Set-ACL -Path $potentialPath
                }
            }
            
            #Unblocks the autologon file so that it can run
            try {
                Unblock-File $AutoLogonLocalPath
            } catch {
                Write-Warning "Unable to unblock file on $hostname"
                return
            }
            #Run the autologon exe
            ##Comment out the try catch block and if else blcok during testing
            try {
                Start-Process "$AutoLogonLocalPath" -ArgumentList "$username","$domain","$password","/accepteula"
                Start-Sleep -Seconds 2
            } catch {
                Write-Warning "Unable to set Autologon"
                Write-Host $_
                return
            }
            #Check to see if autologon succeeded
            $registryusername = (Get-ItemProperty -Path $RegistryPath -Name $UserNameKey -ErrorAction SilentlyContinue).DefaultUserName
            if($registryusername -eq $username) {
                Write-Host "Autologon for $hostname successfully updated" -ForegroundColor Green
            } else {
                Write-Warning "Autologon for $hostname failed"
                return
            }
            #Remove the AutoLogon.exe file
            try {
                Remove-Item -Path $AutoLogonLocalPath -ErrorAction Stop
            } catch {
                Write-Warning "Unable to remove Autologon.exe from $hostname"
            }

        }
    }
    ##Comment out this block during testing
    try {
        Restart-Computer -ComputerName "$hostname.$domainname" -Force -ErrorAction Stop
    } catch {
        Write-Warning "Unable to restart $hostname"
        continue
    }
}
