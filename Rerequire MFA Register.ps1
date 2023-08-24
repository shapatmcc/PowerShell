<#
Script Name:      "Re-require MFA Register"
Written by:       Shaun McCubbin"
Created on:       05/12/21"
Last modified on: 05/14/21"
Purpose:	      This script prompts for a username and resets their MFA status
#>

#Gets modules ready
$module = Import-Module MSOnline -PassThru -ErrorAction Ignore
if(!$module)
{
    Install-Module MSOnline
}

#Gather variables and log into Microsoft Online
$domain = "DOMAIN HERE"
$cred = Get-Credential -UserName "$env:USERNAME@$domain" -Message "Please enter your password"
Connect-MsolService -Credential $cred
$usernameprompt = Read-Host "What username's MFA would you like to reset? Please include the domainappriss.com portion"
#Search for username
$usernameresult = Get-MsolUser -UserPrincipalName $usernameprompt
#proceed only if username is found
if($usernameresult)
{
    $blankauthmethods = @()
    $currentauthmethods = $usernameresult.StrongAuthenticationMethods
    #proceed only if the user has any current authentication methods
    if($currentauthmethods)
    {
        #Reset MFA method to blank
        Set-MsolUser -UserPrincipalName $usernameprompt -StrongAuthenticationMethods $blankauthmethods
        Write-Host "Reset for user $usernameprompt"
    }
    else
    {
        Write-Host "No authentication methods for this user found"
    }

}
else
{
    Write-Host "Unable to find username. Please try again."
}

if ($Host.Name -eq "ConsoleHost")
{
    Read-Host "Press Enter to exit"
}
