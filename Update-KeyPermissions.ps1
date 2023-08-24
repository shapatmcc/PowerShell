#Description: This gives permissions to a certain user to access keys within the registry. It also adds a timeout variable for services
#Assumptions: This needs to be run on the computer you wish to make changes to, or you can invoke a command. 
 function Update-KeyPermissions {
    try {
        # Attempt to modify registry permissions on each key, add or replace with your own keys
        $keys = @(
            "HKLM:\SOFTWARE\ODBC",
            "HKLM:\SOFTWARE\ORACLE",
            "HKLM:\SOFTWARE\WOW6432Node\ODBC",
            "HKLM:\SOFTWARE\WOW6432Node\ORACLE"
        )
    foreach ($key in $keys) {
        if (Test-Path $key) {
            $acl = Get-Acl -Path $key
            $domainUser = "DOMAIN\USERNAME"  # Replace with the domain user you want to grant permissions to

            $accessRule = New-Object System.Security.AccessControl.RegistryAccessRule($domainUser, "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
            $acl.SetAccessRule($accessRule)
            Set-Acl -Path $key -AclObject $acl
        }
    }
        Write-Host "Permissions checked and updated" -NoNewline
    }
    catch {
        Write-Host "Registry permissions error"
        Write-Host $_.Exception.Message
    }

    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
    $registryName = "ServicesPipeTimeout"
    $registryValue = 120000

    if(-not (Test-Path -Path "$registryPath\$registryName")){
        New-ItemProperty -Path $registryPath -Name $registryName -Value $registryValue -PropertyType DWORD -Force | Out-Null
    }
}
