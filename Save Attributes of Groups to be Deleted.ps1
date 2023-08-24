<#
Script Name:      "Save Attributes of Groups to be Deleted"
Written by:       Shaun McCubbin"
Created on:       02/04/21"
Last modified on: 01/02/23"
Purpose:	      Pick a file and store the attributes of a group there before it's deleted
Assumptions:	  This script is being ran from a machine that has the following PowerShell modules installed: AD 
#>

#Splits the email entries by whatever character specified
Function SplitBy
{
    Param([string]$splitCharacter)

    if($script:Groups -match $splitCharacter){
        $script:Groups = $script:Groups -split $splitCharacter
    }
}

#create file picker
Add-Type -AssemblyName System.Windows.Forms
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
    InitialDirectory = [Environment]::GetFolderPath('Desktop') 
    Filter = 'Text Document (*.txt)|*.txt'    
    
}
$null = $FileBrowser.ShowDialog()
$log = $FileBrowser.FileName

#Set up groups variable
$Groups = @()
#Ask for groups pasted from Excel file
$Groups = Read-Host -Prompt "What groups are being removed?"

#Turn the variable into an array, one entry per line
SplitBy([Environment]::NewLine)

foreach($Group in $Groups){
    
    $Members = @()
    $MembersOf = @()
    $props = @()

    $Members = (Get-ADGroup $group -Properties member | Select-Object -ExpandProperty member | Get-ADObject -Properties name).name
    $MembersOf = (Get-ADGroup $group -Properties memberof | Select-Object -ExpandProperty memberof | Get-ADObject -Properties name).name
    $props = Get-ADGRoup $Group -Properties * | select *
    if($props -match ";"){
        $props = $props -split ";"
    }
    $spaces = [Environment]::NewLine
    Add-Content $log -Value $props
    Add-Content $log -Value "Members:"
    Add-Content $log -Value $members
    Add-Content $log -Value "Member Of:"
    Add-Content $log -Value $membersof
    Add-Content $log -Value $spaces

    
}

#############################################################################################
###NOTE: Do not uncomment below unless you want to delete the groups pasted in the command###
#############################################################################################

<#foreach($Group in $Groups){
    Remove-ADGroup -Identity $Group
}#>
