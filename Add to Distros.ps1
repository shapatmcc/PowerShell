
<#
Script Name:      Add External Contact to Group"
Written by:       Shaun McCubbin"
Created on:       06/18/19"
Last modified on: 01/02/23"
Purpose:	      
Assumptions:	  This script is being ran from a server that has the following PowerShell modules installed: AD 
                  You have Exchange Powershell installed
#>

#**************************************
#******* Setting up functions ******
#**************************************

#If running in the console, wait for input before closing.
Function PressToExit
{
    if ($Host.Name -eq "ConsoleHost")
    {
        Write-Host "Press any key to exit..."
        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") > $null
    }
    break
}

#Writes out where the logs can be found
Function OpComplete
{
    Param ([boolean]$isOpComplete)

    Write-Host " "
    if ($isOpComplete -eq $true){
        Write-Host -ForegroundColor Green "Operation Complete."
    }
    Write-Host -ForegroundColor Green "Logs can be found at $contactlogs"
    Write-Host " "
}

#Adds to the log file
Function WriteLog
{
   Param ([string]$logstring, [string]$color)

   Write-Host -ForegroundColor $color $logstring
   $logstring = "$(Get-Date -DisplayHint DateTime) - $env:UserName - " + $logstring
   Add-content $contactlogs -value $logstring
}

#Splits the email entries by whatever character specified
Function SplitBy
{
    Param([string]$splitCharacter)

    if($script:EmailsFromTxt -match $splitCharacter){
        $script:EmailsFromTxt = $script:EmailsFromTxt -split $splitCharacter
    }
}

#Removes any character or phrase specified
Function RemoveSpaces
{
    Param([string]$remove, [string]$replace)
    if($script:entry -match $remove){
        $script:entry = $script:entry -replace $remove, $replace
    }

}

#Function to flash window
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Runtime.InteropServices;

public class Window
{
    [StructLayout(LayoutKind.Sequential)]
    public struct FLASHWINFO
    {
        public UInt32 cbSize;
        public IntPtr hwnd;
        public UInt32 dwFlags;
        public UInt32 uCount;
        public UInt32 dwTimeout;
    }

    //Stop flashing. The system restores the window to its original state. 
    const UInt32 FLASHW_STOP = 0;
    //Flash the window caption. 
    const UInt32 FLASHW_CAPTION = 1;
    //Flash the taskbar button. 
    const UInt32 FLASHW_TRAY = 2;
    //Flash both the window caption and taskbar button.
    //This is equivalent to setting the FLASHW_CAPTION | FLASHW_TRAY flags. 
    const UInt32 FLASHW_ALL = 3;
    //Flash continuously, until the FLASHW_STOP flag is set. 
    const UInt32 FLASHW_TIMER = 4;
    //Flash continuously until the window comes to the foreground. 
    const UInt32 FLASHW_TIMERNOFG = 12; 


    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool FlashWindowEx(ref FLASHWINFO pwfi);

    public static bool FlashWindow(IntPtr handle, UInt32 timeout, UInt32 count)
    {
        IntPtr hWnd = handle;
        FLASHWINFO fInfo = new FLASHWINFO();

        fInfo.cbSize = Convert.ToUInt32(Marshal.SizeOf(fInfo));
        fInfo.hwnd = hWnd;
        fInfo.dwFlags = FLASHW_ALL | FLASHW_TIMERNOFG;
        fInfo.uCount = count;
        fInfo.dwTimeout = timeout;

        return FlashWindowEx(ref fInfo);
    }
}
"@

if ($Host.Name -eq "ConsoleHost"){
    $pshost = get-host
    $pswindow = $pshost.ui.rawui
    $newsize = $pswindow.windowsize
    $newsize.height = 30
    $newsize.width = 120
    $pswindow.windowsize = $newsize
}

#**************************************
#******* Declaring variables **********
#**************************************

$ContactPath = "Path for Contacts in AD HERE"
$Domain = "DOMAIN NAME HERE"
$nochanges = @()
$handle = (Get-Process -ID $PID).MainWindowHandle
$DCServer = (Get-ADDomainController -Discover -DomainName $Domain -ForceDiscover -Service "PrimaryDC").Name + $Domain
$LogPath = "PATH NAME HERE"
$TestExchangeGroup = "ENTER TEST GROUP IN EXCHANGE HERE. THIS CHECKS IF YOU HAVE AN ACTIVE CONNECTION TO EXCHANGE"
$UserPrincipalDomain = "USER PRINCIPAL DOMAIN HERE"

#**************************************
#******* Gathering variables **********
#**************************************

#Prepare log file
Set-Variable -Name contactlogs -Value "$LogPath\Distro_Script_Log_$(Get-Date -Format yyyyMMdd).txt"
try {
    if(!(Test-Path -Path $contactlogs -ErrorAction stop)){
        New-Item -Path $contactlogs -ErrorAction stop -ItemType file | Out-Null
    }
}
catch {
    Write-Host -ForegroundColor Red "Log file not created. Please check that you have access to the log path variable, then try again"
    PressToExit
}

#Gather emails to be added
try {
    #Gather emails from txt file on Desktop
    $EmailsFromTxt = @(get-content -Path C:\Users\$env:UserName\Desktop\ExternalContacts.txt -ErrorAction stop)
    Write-Host "File 'Desktop\ExternalContacts.txt' found"
}
catch {
    #If file on desktop doesn't exist, it prompts you for the users in the window instead
    $EmailsFromTxt = @()
    if ($Host.Name -eq "ConsoleHost"){
        $input = ""
        $c = 0
        do {
	        if($c -eq 0){
                Write-Host "What emails are being added? Add a semicolon to the end of your list and press Enter:"
                $input = Read-Host 
            }else{
                $input = Read-Host 
            }
            If ($input -ne $NULL) {
		        $EmailsFromTxt += $input
	        }
            $c++
        } While($input -notlike "*;") 
    }else{
        $EmailsFromTxt = Read-Host -Prompt "What emails are being added?"
    }
    cls
}
$EmailsFromTxt = @($EmailsFromTxt | ? {$_ -match '\w'})
if(!$EmailsFromTxt){
    if((Test-Path -Path C:\Users\$env:UserName\Desktop\ExternalContacts.txt -ErrorAction SilentlyContinue)){
        WriteLog "No entries were found in ExternalContacts.txt on your Desktop" "Red"
        Write-Host -ForegroundColor Red "Rename the txt file if you would like to paste your entries within this prompt. Then run the script again"       
    }else{
        WriteLog "No entries were found to add to Active Directory" "Red"
    }
    OpComplete $false
    PressToExit
}

#Prompt for AD group to add contacts to
$group = Read-Host -prompt "What group are these contacts being added to? Please paste the group name from AD"
cls
Write-Host "Loading..."

#Verifies that group exists
$AD = $true
try{
   $group = (get-adgroup -identity $group -Server $DCServer).Name
}
catch{
    #test connection to Exchange
    try{
        $exopsuser = $env:UserName + $userPrincipalDomain
        Add-DistributionGroupMember -Identity $TestExchangeGroup -Member $exopsuser -ErrorAction Stop | out-null
        Remove-DistributionGroupMember -Identity $TestExchangeGroup -Member $exopsuser -ErrorAction Stop -Confirm:$false | out-null
    } catch{
        #if no connection, connection is attempted. Begin loop
        do
        {
          #Attempt connection to Exchange
          try{
            $MFAExchangeModule = ((Get-ChildItem -ErrorAction SilentlyContinue -Path $($env:LOCALAPPDATA+"\Apps\2.0\") -Filter CreateExoPSSession.ps1 -Recurse ).FullName | Select-Object -Last 1)
            . "$MFAExchangeModule"
            cls
            Write-Host "Loading..."

            Connect-EXOPSSession -UserPrincipalName $exopsuser
            cls
            Write-Host "Loading..."

            #once connection is established, check priveleges
            try{
                $Exchangetest = $false
                Add-DistributionGroupMember -Identity $TestExchangeGroup -Member $exopsuser -ErrorAction Stop | out-null
                Remove-DistributionGroupMember -Identity $TestExchangeGroup -Member $exopsuser -ErrorAction Stop -Confirm:$false | out-null
                $Exchangetest = $true
            } catch{
                WriteLog "No access. Please make sure you have the Exchange Administrator PIM activated. Unable to activate PIM Role" "Red"
                Read-Host "Press Enter to try again or close this window"
                }
        } catch{
            #if connection fails, user is notified and script exits
            WriteLog "Unable to connect to Exchange"
            PressToExit
        }  
        #Exchange test is made true once both commands have passed
        } while (!$Exchangetest)
    }

    try{
        $group = (Get-DistributionGroup -Identity $group -ErrorAction Stop).DisplayName
        $AD = $false
    } catch{
        WriteLog "'$group' group does not exist" "Red"
        OpComplete $false
        PressToExit
    }

}

#Gather members of the AD group
if($AD){
    $members = (Get-ADGroup $group -Properties member -Server $DCServer | Select-Object -ExpandProperty member | Get-ADObject -Properties mail -Server $DCServer).mail
}else{
    $members = (Get-DistributionGroupMember -Identity $group -ResultSize Unlimited | select primarysmtpaddress).primarysmtpaddress
}

#**************************************
#********* Starting the script ********
#**************************************

#Separate the emails by new line and commas
SplitBy([Environment]::NewLine)
SplitBy(", ")
SplitBy(",")
SplitBy("; ")
SplitBy(";")

#Check for specific possible spaces within email entries
$i=0
foreach($entry in $EmailsFromTxt){
    RemoveSpaces '@\s+(\w)' '@$1'
    RemoveSpaces '(\w)\s+@' '$1@'
    RemoveSpaces '(\w)\s+\.(\w\w)' '$1.$2'
    RemoveSpaces '(\w)\s+\.(\w\w\w)' '$1.$2'
    RemoveSpaces '(\w)\.\s+(\w\w)' '$1.$2'
    $EmailsFromTxt[$i] = $entry
    $i++
}
#Split emails by any space left and remove any entries containing only spaces
$EmailsFromTxt = $EmailsFromTxt -split " "
$EmailsFromTxt = $EmailsFromTxt | ? {$_ -match '\w'} 

cls

#Once group is verified, it starts to check if each entry is a contact and which of those are in the group
foreach($email in $EmailsFromTxt) {
    #$email = $email -replace '\s+', ''
    $Filter = "(proxyaddresses -eq 'smtp:"+$email+"') -or (mail -eq '"+$email+"')"
    #is entry an email address
    if(($email -like '?*@?*.??') -or ($email -like '?*@?*.???')){
        if ($email -notlike "*@*@*"){
            #does the entry already exist as a contact
            if(Get-ADObject -Filter $Filter -Server $DCServer){
                #does the contact belongs to group
                if($members -contains $email){
                    WriteLog "$email exists in the group $group. Nothing added" "Yellow"
                    $nochanges += $email
                #contact does not belong to group
                 }else{
                    #contact is added to the $add list
                    if($add -notcontains $email){
                        $add += $email
                    }
                }
            #contact does not exist
            }else{
                #contact is added to $create list 
                if($create -notcontains $email){            
                    $create += $email
                }
            }
        }else{
            #two @ signs are discovered in a string
            WriteLog "$email is not a valid email address" "Red"
            $nochanges += $email
        }
    #entry is not valid email address
    }else{
        WriteLog "$email is not a valid email address" "Red"
        $nochanges += $email
    }
#ends loop
}

#checks if any emails need to be added or created
if(($add) -or ($create)){
    if($nochanges){
        Write-Host ""
        #If the script is running in Console Host, it will ask them to press any key to continue
        if ($Host.Name -eq "ConsoleHost"){
            Write-Host "Press any key to continue..."
            $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") > $null
        }
    }
    #if there are any contacts that already exist but not in the specified group
    if($add -ne $null){
        #List out any emails that will be added to the group
        Write-Host -ForegroundColor DarkCyan "The following contacts will be added to the group $group`:"
        foreach($emailAdd in $add){
            Write-Host $emailAdd
        }
        Write-Host ""
    }
    #If there are any contacts that do not exist in the system
    if($create -ne $null){
        #List out any emails that will be created AND added to the specified group
        Write-Host -ForegroundColor DarkCyan "The follwing contacts will be created and then added to $group"
        Write-Host -ForegroundColor DarkCyan "Their name AND email will display as follows within the quotation marks:"
        foreach($emailCreate in $create){
            Write-Host `"$emailCreate`"
        }
        Write-Host ""
    }
    #Ask if the user would like to continue in case they see a mistake
    $response = Read-Host -Prompt "Do you wish to continue? ['Y' for yes; anything else for no]"
    if ($response -like 'y*'){
        #add each email in the array to the AD group
        foreach($emailToAdd in $add){
            try{
                if($AD){
                    $Filter = "(proxyaddresses -eq 'smtp:"+$emailToAdd+"') -or (mail -eq '"+$emailToAdd+"')"
                    $contact = Get-ADObject -Server $DCServer -filter $Filter -properties distinguishedName, displayname
                    set-adgroup -identity $group -Server $DCServer -add @{'member'=$contact.distinguishedName}
                } else{
                    $contact = (Get-MailContact -Identity $emailToAdd -ErrorAction Ignore).guid
                    if(!$contact)
                    {
                        $contact = (Get-User -Identity $emailToAdd).guid
                    }
                    Add-DistributionGroupMember -Identity $group -Member $contact.guid -ErrorAction stop
                }
                WriteLog "$emailToAdd added to the group $group" "White"
            }catch{
                WriteLog "$emailToAdd NOT added. An error occurred." "Red"
            }
        }
        #create each email in the array as a contact and add to the AD group
        foreach($emailToCreate in $create){
            $Filter = "(proxyaddresses -eq 'smtp:"+$emailToCreate+"') -or (mail -eq '"+$emailToCreate+"')"
            New-ADObject -Server $DCServer -Name $emailToCreate -Type "contact" -DisplayName $emailToCreate -Path $ContactPath -OtherAttributes @{'mail'=$emailToCreate; 'proxyAddresses'=('SMTP:'+$emailToCreate)}
            WriteLog "$emailToCreate added as a contact" "White"
            #waits for the new contact to show up in search. Usually takes about 8 seconds or less
            $sleep = 0
            while (!(Get-ADObject -Filter $Filter -Server $DCServer) -and ($sleep -le 24)){
                Start-Sleep -Seconds 4
                $sleep += 4
            }
            #If the process takes too long, the loop will cancel and the contact will not be added to the group
            if ($sleep -ge 24){
                WriteLog "$emailToCreate was unsuccessfully added to the group due to a timeout error" "White"
            }else{
                #add newly created contact to the group
                try{
                    if($AD){
                        $contact = Get-ADObject -filter $Filter -properties distinguishedName, displayname
                        set-adgroup -identity $group -Server $DCServer -add @{'member'=$contact.distinguishedName} -ErrorAction stop
                        WriteLog "$emailToCreate added to the group $group" "White"
                    } else{
                        WriteLog "$emailToCreate NOT added to $group. Waiting for Exchange sync" "Yellow"
                        #Add-DistributionGroupMember -Identity $group -Member $contact.displayname
                    }
                }catch{
                    WriteLog "$emailToCreate NOT added to group. An error occurred." "Red"
                }
            }
        }
        #if it's an exchange group and there were contacts created
        if(!$AD -and $create){
            OpComplete $false
            Write-Host ""
            Write-Host "Waiting for Exchange sync." -ForegroundColor DarkCyan
            Write-Host "NOTE: This may take up to an hour. Please wait and the window will flash when done" -ForegroundColor Yellow
            Write-host "You may copy the entries below and exit to add manually or let the script try again in 5 minutes:" -ForegroundColor DarkCyan
            Write-Host ""
            echo $create
            Write-Host ""
	    
            while (!(Get-MailContact -Identity $create[$create.count - 1] -ErrorAction SilentlyContinue)){
                Start-Sleep -Seconds 300
                Write-Host "$(Get-Date -DisplayHint DateTime) - Waiting for sync. Will check again in 5 minutes" -ForegroundColor Yellow
            }
            #once done, window flashes
            if ($Host.Name -eq "ConsoleHost"){
                [window]::FlashWindow($handle,500,5) | out-null
            }
            Write-Host ""
            foreach($emailToCreate in $create){
                $contact = (Get-MailContact -Identity $emailToCreate).guid
                try{ 
                    Add-DistributionGroupMember -Identity $group -Member $contact.guid -ErrorAction stop
                    WriteLog "$emailToCreate added to the group $group" "White"
                }catch{
                    WriteLog "$emailToCreate NOT added to group. An error occurred." "Red"
                }
            }
            
        }

        #Once the contacts are created/added, the script will end
        OpComplete $true
        PressToExit
    }else{
        #If the user rejects the proposed changes, the script will end
        WriteLog "No changes were made. User canceled any additions to the group $group" "Yellow"
        OpComplete $false
        PressToExit
    }
}else{
    #If there are no emails to add or create, the user will not be prompted, and the script will end
    OpComplete $true
    PressToExit
}

# *****************************************************************
# **************** THIS IS THE BOTTOM OF THE SCRIPT  ***************
# *****************************************************************
