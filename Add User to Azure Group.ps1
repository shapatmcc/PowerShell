<#
Script Name:      "Add User to Azure Group"
Written by:       Shaun McCubbin"
Created on:       12/08/21"
Last modified on: 12/21/22"
Purpose:	      
Assumptions:	  This script is being ran from a machine that has the following PowerShell modules or packages installed:
                  Nuget, AzureADPreview, msal.ps
#>

#**************************************************
#******************VARIABLES*************************
#**************************************************
$ClientID = "CLIENT ID FOR AZURE HERE"
$tenantID = "TENANT ID HERE"
$groupToAdd = "PUT AZURE GROUP HERE"
$UserToAdd = "PUT USER PRINCIPAL NAME HERE"
$Domain = "ENTER ON PREM AD DOMAIN NAME HERE"
$AzureDomain = "ENTER AZURE DOMAIN NAME HERE"

#**************************************************
#******************MODULES*************************
#**************************************************

Write-Host "Checking for modules..."
#****Install Nuget****
$provider = Get-PackageProvider NuGet -ErrorAction Ignore -WarningAction SilentlyContinue
#if Nuget not found
if (-not $provider)
{
    #check if powershell is running as admin. If not, reopen the script as admin and close the current window
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }
    Write-Host "If this is your first time running the script, you may have to repeat the above steps a few times in order to make sure everything is installed." -ForegroundColor Yellow
    #Try installing Nuget
    try
    {
    Write-Host "Installing provider NuGet. After this is complete, Powershell will restart."
    #Find-PackageProvider -Name NuGet -ForceBootstrap -IncludeDependencies
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force -ErrorAction Stop -WarningAction SilentlyContinue -Confirm:$false | Out-Null
    #once installed, the script restarts
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit
    }
    #If installing Nuget fails
    catch
    {
        #Provide error message
        $ErrorMessage = "Error installing Nuget: " + $_.Exception.Message
        Write-Host $ErrorMessage -ForegroundColor Red
        #Check TLS version
        if($([Net.ServicePointManager]::SecurityProtocol) -notmatch "Tls12")
        {
            #Change Regedit keys to make TLS 1.2 available
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord
            Write-Host "Changes to security protocols made. Please close and reopen this script in a Powershell admin window and try again."
            Write-Host "If this is your first time running the script, you may have to repeat the above steps a few times in order to make sure everything is installed." -ForegroundColor Yellow
            #once changed, the script restarts
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit
        }
        if ($Host.Name -eq "ConsoleHost")
        {
            Read-Host "Press Enter to exit"
        }
        break
    }
}

#****Install AzureADPreview****
$module = Import-Module AzureADPreview -PassThru -ErrorAction Ignore
#if AzureADPreview not found
if (-not $module)
{
    #check if powershell is running as admin. If not, reopen the script as admin and close the current window
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }
    #try Installing AzureADPreview
    try
    {
        Write-Host "Installing module AzureADPreview. After this finishes, Powershell will restart. "
        Install-Module AzureADPreview -AllowClobber -Force -Confirm:$false
        #once installed, the script will restart
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit
    }
    #if install fails
    catch
    {
        #provide error message
        $ErrorMessage = "Error installing AzureADPreview module: " + $_.Exception.Message
        Write-Host $ErrorMessage -ForegroundColor Red
        Write-Host ""
        Write-Host "If this is your first time running the script, you may have to repeat the above steps a few times in order to make sure everything is installed." -ForegroundColor Yellow
        if ($Host.Name -eq "ConsoleHost")
        {
            Read-Host "Press Enter to exit"
        }
        break
    }
}
Import-module AzureADPreview

#****Install msal.ps****
$module = Import-Module PowerShellGet
try
{
    #if PowerShellGet cannot be found
    if(!(Get-Module | Where-Object {$_.Name -eq 'PowerShellGet' -and $_.Version -ge '2.2.4.1'}))
    {
        #checks if powershell is running as admin. If not, it restarts in an admin powershell window
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }
        #Installs PowershellGet
        Write-Host "Installing PowerShellGet. Powershell will restart after this finishes."
        Install-Module PowerShellGet -Force -Confirm:$false | out-null
        #powershell restarts
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit
    }
    #If MSAL.PS package is not found
    if(!(Get-Package msal.ps -WarningAction SilentlyContinue -ErrorAction SilentlyContinue)) 
    {
        #Checks if powershell is running as admin. If not, it restarts in an admin powershell window
        if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }
        #Installs MSAL.PS
        Write-Host "Installing Msal.ps. Powershell will restart after this finishes."
        Install-Package msal.ps -Confirm:$false| out-null
        #Restart powershell after install is complete
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit
    }
}
#If install fails
catch
{
    #Provide error message and quit
    $ErrorMessage = "Error installing msal.ps module: " + $_.Exception.Message
    Write-Host $ErrorMessage -ForegroundColor Red
    if ($Host.Name -eq "ConsoleHost")
    {
        Read-Host "Press Enter to exit"
    }
    break
}
$username = $env:USERNAME + "@" + $AzureDomain
# Get token for MS Graph with MFA, first attempt is silently without prompting
try
{
    $MsResponse = Get-MSALToken -Scopes @("https://graph.microsoft.com/.default") -ClientId $clientID -RedirectUri "urn:ietf:wg:oauth:2.0:oob" -Authority "https://login.microsoftonline.com/common" -Silent -LoginHint $username -ExtraQueryParameters @{claims='{"access_token" : {"amr": { "values": ["mfa"] }}}'}
}
catch
{
    #if necessary, it will propmpt for MFA
    try
    {
        $MsResponse = Get-MSALToken -Scopes @("https://graph.microsoft.com/.default") -ClientId $clientID -RedirectUri "urn:ietf:wg:oauth:2.0:oob" -Authority "https://login.microsoftonline.com/common" -Interactive -ExtraQueryParameters @{claims='{"access_token" : {"amr": { "values": ["mfa"] }}}'}
    }
    catch
    {
        #Provide error message and quit
        $ErrorMessage = "Error connecting to Azure: " + $_.Exception.Message
        Write-Host $ErrorMessage -ForegroundColor Red
        if ($Host.Name -eq "ConsoleHost")
        {
            Read-Host "Press Enter to exit"
        }
        break
    }
}
#$username = ((Get-MSALToken -Scopes @("https://graph.microsoft.com/.default") -ClientId $clientID -RedirectUri "urn:ietf:wg:oauth:2.0:oob" -Authority "https://login.microsoftonline.com/common" -Silent -LoginHint $username -ExtraQueryParameters @{claims='{"access_token" : {"amr": { "values": ["mfa"] }}}'}).Account).Username

# Get token for AAD Graph
$AadResponse = Get-MSALToken -Scopes @("https://graph.windows.net/.default") -ClientId $clientID -RedirectUri "urn:ietf:wg:oauth:2.0:oob" -Authority "https://login.microsoftonline.com/common"

#Log into AzureAD
try
{
    Write-Host "Logging in to Azure..."
    Connect-AzureAD -AadAccessToken $AadResponse.AccessToken -MsAccessToken $MsResponse.AccessToken -AccountId: $username -tenantId: $tenantID | out-null
}
catch
{
    #Provide error message and quit
    $ErrorMessage = "Error connecting to Azure: " + $_.Exception.Message
    Write-Host $ErrorMessage -ForegroundColor Red
    if ($Host.Name -eq "ConsoleHost")
    {
        Read-Host "Press Enter to exit"
    }
    break
}

function AddUserToAzureGroup {
    [cmdletbinding()]
    param (
        [string]$groupToAdd,
        [string]$Users,
        [Parameter (Mandatory = $true)]
        [string]$DomainName
    )
    $DCServer = (Get-ADDomainController -Discover -DomainName $DomainName -ForceDiscover).Name + "." + $DomainName
    if($groupToAdd -eq "")
    {
        $groupToAdd = Read-Host "Type in the name of the group"
    }
    $groupid = (Get-AzureADGroup -SearchString "$groupToAdd").objectId
    if($groupid.Count -gt 1)
    {
        Read-host "Your group name returned more than one search result and thus the script must exit"
        break
    }

    if($Users -eq "")
    {
        $Users = Read-Host "Type in the user to add to the group $groupToAdd"
    }
    
    #Turn the variable into an array, one entry per line
    $splitCharacter = [Environment]::NewLine
    if($Users -match $splitCharacter){
            $Users = $Users -split $splitCharacter
        }
    $Users = $Users | ? {$_ -match '\w'} 
    $SamAccountName = @()
    $Email = @()
    $Name = @()
    foreach ($user in $Users) {
        $Filter = "DisplayName -like '"+$user+"*'"
        $SamAccountName += (Get-ADUser -Server $DCServer -Filter $Filter).sAMAccountName
        $Email += (Get-ADUser -Server $DCServer -Filter $Filter -Properties mail).mail
        #$LastName = (Get-ADUser -Filter $Filter -Properties LastName).LastName
        #$FirstName = (Get-ADUser -Filter $Filter -Properties FirstName).FirstName
        #$Name += "$LastName, $FirstName"
    }
    if($Email.Count -gt 1)
    {
        Read-Host "More than one entry is not allowed"
        break
    }


    $userobject = ""
    $userobject = (Get-AzureADUser -ObjectId "$Email").objectId
    try
    {
    Add-AzureADGroupMember -ObjectId "$groupid" -RefObjectId "$userobject"
    Read-Host "Successfully added to group $groupToAdd"
    }
    catch
    {
        $message = $Error[0].Exception.ErrorContent.Message.Value
        $alreadyexists = "One or more added object references already exist for the following modified properties: 'members'."
        if($message -eq  $alreadyexists)
        {
            Read-Host "User is already a member of group $groupToAdd"
        }
        else
        {
            Write-Host "Unknown error"
        }
    }
}
