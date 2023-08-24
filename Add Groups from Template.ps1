<#
Script Name:      "Add Groups from Template"
Written by:       Shaun McCubbin"
Created on:       12/04/20"
Last modified on: 12/21/22"
Purpose:	      
Assumptions:	  This script is being ran from a machine that has the following PowerShell modules installed: AD 
#>
function AddGroupsFromTemplate {
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$DomainName,
        [string]$TargetTemplate,
        [string]$TargetUser
    )
    #finds the primary server so that it can make changes to Active Directory
    $DCServer = (Get-ADDomainController -Discover -DomainName $DomainName -ForceDiscover -Service "PrimaryDC").Name + "." + $DomainName
    $TemplateGroups = @()
    $UserGroups = @()
    $finalgroups = @()
    
    #prompts for the name of the template that a user is being compared to
    do {
        if(!$TargetTemplate)
        {
            $TargetTemplate = Read-Host "Please enter the username of the template"
        }
        try {
            $TemplateGroups = @((Get-ADPrincipalGroupMembership -Identity $TargetTemplate -Server $DCServer).Name)
        } catch {
            Write-Host "Error: User not found. Try again"
            $TargetTemplate = ""
        }
    } until ($TemplateGroups)
    
    #prompts for the name of the user that groups are being added to
    do {
        if(!$TargetUser)
        {
            $TargetUser = Read-Host "Please enter the username to add the template to"
        }
        try {
            $UserGroups = @((Get-ADPrincipalGroupMembership -Identity $TargetUser -Server $DCServer).Name)
        } catch {
            Write-Host "Error: User not found. Try again"
            $TargetUser = ""
        }
    } until ($UserGroups)

    #for each group in the template, it checks if the user is already in the group
    foreach($group in $TemplateGroups) 
    {
        #if the user doesn't already have this group
        if ($UserGroups -notcontains $group)
        {
            #add to list of groups that user needs
            $finalgroups += $group    
        } else {
            Write-Host "$TargetUser already a part of $group"
        }
    }

    Write-Host "These are the groups we will add to $TargetUser :"
    echo $finalgroups

    Read-Host "Press Enter to continue or close this window to cancel"
    
    #if the person running this script continues after the Read Host, the user will be added to all the groups from the template that the user was not already in
    foreach($group in $finalgroups){
        try{
            Add-ADGroupMember -Identity $group -Members $TargetUser -Server $DCServer
            Write-Host "Added to $group"
        } catch {
            Write-Host "Error: could not add to $group" -ForegroundColor Red
        }
    }

    if ($Host.Name -eq "ConsoleHost"){
        Read-Host "Press Enter to exit"
    }
}
