<#
Script Name:      "Get Email and Display Names"
Written by:       Shaun McCubbin"
Created on:       09/04/19"
Last modified on: 01/02/23"
Purpose:	      
Assumptions:	  This script is being ran from a machine that has the following PowerShell modules installed: AD 
#>
#Splits the email entries by whatever character specified
Function SplitBy
{
    Param([string]$splitCharacter)

    if($script:Users -match $splitCharacter){
        $script:Users = $script:Users -split $splitCharacter
    }
}

#Gather variables
$Domain = "DOMAINNAME HERE"
$DCServer = (Get-ADDomainController -Discover -DomainName $Domain -ForceDiscover).Name + $Domain
$Users = Read-Host -Prompt "Enter users"

#Turn the variable into an array, one entry per line
SplitBy([Environment]::NewLine)
$Users = $Users | ? {$_ -match '\w'} 

#Gather emails and usernames of all entries
$SamAccountName = @()
$Email = @()
$Name = @()
foreach ($user in $Users) {
    $Filter = "DisplayName -like '"+$user+"*'"
    $SamAccountName += (Get-ADUser -Server $DCServer -Filter $Filter).sAMAccountName
    $Email += (Get-ADUser -Server $DCServer -Filter $Filter -Properties mail).mail
}

$userresponse = Read-Host "Press e for emails or u for usernames"
if($userresponse -like "e")
{
    $Email
}
elseif($userresponse -like "u")
{
    $SamAccountName
}
