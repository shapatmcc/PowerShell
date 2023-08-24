<#
Script Name:      "UPS Label Maker"
Written by:       Shaun McCubbin"
Created on:       08/07/21"
Last modified on: 01/02/23"
Purpose:	  This makes a file that can be imported via batch on ups.com 
Assumptions:	  You need a csv file on your Desktop named returnbatchtemplate.csv
#>

#####################################
#####NOTE: See below for entering return name and return address
#####################################

#Load file and ask if user wants to clear records
$filepath = "C:\Users\$env:USERNAME\Desktop\returnbatchtemplate.csv"
$upslabels = @(Get-Content -Path $filepath)
if($upslabels.Count -gt 0)
{
    $delete = Read-Host "Do you want to clear the existing records? Y for yes"
    if($delete -like "y")
    {
        $upslabels = ""
        Set-Content -Path $filepath -Value $upslabels
    }
}

Function PromptForLabels
{
    Param ([string]$service, 
    [string]$description, 
    [int]$weight, 
    [string]$signature, 
    [string]$contactName, 
    [string]$addresstosplit,
    [string]$returnname)

    #Declare variables
    $country = "US"
    $packaging = "2"
    $upslabels = @(Get-Content -Path $filepath)
    $address = ""
    $address2 = ""
    $city = ""
    $state = ""
    $zipcode = ""

    #Split address
    $wholeaddress = @($addresstosplit -split ", ")
    if($wholeaddress.Count -eq 4){
        $address = $wholeaddress[0]
        $address2 = $wholeaddress[1]
        $city = $wholeaddress[2]
        $State = ($wholeaddress[3] -split " [0-9][0-9][0-9][0-9][0-9]")[0]
        $zipcode = ($wholeaddress[3] -split "[A-Z][A-Z] ")[1]
    }
    elseif($wholeaddress.Count -eq 3){
        $address = $wholeaddress[0]
        $city = $wholeaddress[1]
        $State = ($wholeaddress[2] -split " [0-9][0-9][0-9][0-9][0-9]")[0]
        $zipcode = ($wholeaddress[2] -split "[A-Z][A-Z] ")[1]
    }

    $stringtoadd = "$contactname,$contactname,$country,$address,$address2,,$city,$state,$zipcode,,,,,$packaging,,$weight,,,,,IT equipment,,,,$service,$signature,,,,,,,,$returnname,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,"
    #add string to arra$y uploaded from file
    if($upslabels){
        $upslabels = $upslabels + $stringtoadd
    }
    else
    {
        $upslabels = @($stringtoadd)
    }
    Set-Content -Path $filepath -Value $upslabels
}

Function Collect-Array
{
    Param ([parameter(Mandatory=$true)][string]$entryrequested)
        $input = ""
        $arraytocollect = @()
    $c = 0
    do {
        $Shiftpressed = ""
        $Enterpressed = ""
	    if($c -eq 0){
            Write-Host $entryrequested
            #Write-Host "When you're done, add in a ';' at the end and press Enter"
            $input = Read-Host 
        }else{
            $input = Read-Host 
        }
        $Enterpressed = [bool]([PsOneApi.Keyboard]::GetAsyncKeyState($enterkey) -eq -32767)
        $Shiftpressed = [bool]([PsOneApi.Keyboard]::GetAsyncKeyState($Shiftkey) -eq -32767)

        If ($input -ne $NULL) {
		    $arraytocollect += $input
	    }
        $c++
    } until($Enterpressed -and !$Shiftpressed) 
    $arraytocollect = $arraytocollect -split ";" 
    $arraytocollect = $arraytocollect -split [Environment]::NewLine
    $arraytocollect = $arraytocollect | ? {$_ -match '\w'}
    return $arraytocollect
}

 # this is the c# definition of a static Windows API method:
$Signature = @'
    [DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
    public static extern short GetAsyncKeyState(int virtualKeyCode); 
'@

# Add-Type compiles the source code and adds the type [PsOneApi.Keyboard]:
Add-Type -MemberDefinition $Signature -Name Keyboard -Namespace PsOneApi

$ShiftKey = 16
$EnterKey = 13


do{
    $namesArray = Collect-Array -entryrequested "Please enter the name of the recipient(s) you would like to add"
    Write-host "Please enter the address(es) in the following format):"
    $addressesArray = Collect-Array -entryrequested "123 Street Name, Apt #, City, KY 40165"
    if($namesArray.count -gt 1)
    {
        $contactsarray = @(0..($namesarray.length-1) | Select-Object @{n="Name";e={$namesarray[$_]}}, @{n="Address";e={$addressesarray[$_]}})
    }
    else
    {
        $contactsarray = @{"Name"=$namesarray; "Address" = $addressesarray}
    }

    $service = Read-Host "Type 01 for Next Day Air, 02 for 2 Day Air, 12 for 3 Day, or 03 for Ground"

    $numberofboxes = Read-Host "How many boxes for each user?"
    $i = 1
    while($i -le $numberofboxes){
        $weight = Read-Host "What is the weight in lbs for box $i"
        $signature = Read-Host "Type Y if signature is required or press Enter if no signature needed"
        if($signature -like 'y')
        {
            $signature = "A"
        }
        else
        {
            $signature = ""
        }
        foreach($contact in $contactsarray)
        {
            $nameentry = $contact.name
            $addressentry = $contact.address
            PromptForLabels -contactName $nameentry -addresstosplit $addressentry -service $service -weight $weight -signature $signature
        }
        $i++
    }

    $numberofreturns = Read-Host "How many returns for each user?"
    $i = 1
    while($i -le $numberofreturns){
        $returnweight = Read-Host "What is the weight in lbs for return box $i"
        $signature = ""
	####Place return name here
        $nameentry = ""
	####Place return address here
        $addressentry = ""
        foreach($contact in $contactsarray)
        {
            $returnname = $contact.name
            PromptForLabels -contactName $nameentry -addresstosplit $addressentry -service $service -weight $returnweight -signature $signature -returnname $returnname
        }
        $i++
    }
    $anotherentry = Read-Host "Type y for another entry or press enter to exit"
}
while($anotherentry)
