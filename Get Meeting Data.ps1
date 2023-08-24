<#
Script Name:      "Get Meeting Data"
Written by:       Shaun McCubbin"
Created on:       06/04/20"
Last modified on: 01/03/23"
Purpose:	      In the early stages of the pandemic, this was created to help us with contact tracing. If someone tested positive for COVID, we
                  could run this to see all the meetings they had been in and who else was in them. 
Assumptions:	  TYou have to have access to the user's mailbox via Exchange
Notes:            The part that pulls the MSGraph data is not my own, I don't recall where I pulled this from. 
#>

Function SelectDate {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object Windows.Forms.Form -Property @{
        StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
        Size          = New-Object Drawing.Size 243, 230
        Text          = 'Select a Date'
        Topmost       = $true
    }

    $calendar = New-Object Windows.Forms.MonthCalendar -Property @{
        ShowTodayCircle   = $false
        MaxSelectionCount = 1
    }
    $form.Controls.Add($calendar)

    $okButton = New-Object Windows.Forms.Button -Property @{
        Location     = New-Object Drawing.Point 38, 165
        Size         = New-Object Drawing.Size 75, 23
        Text         = 'OK'
        DialogResult = [Windows.Forms.DialogResult]::OK
    }
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $cancelButton = New-Object Windows.Forms.Button -Property @{
        Location     = New-Object Drawing.Point 113, 165
        Size         = New-Object Drawing.Size 75, 23
        Text         = 'Cancel'
        DialogResult = [Windows.Forms.DialogResult]::Cancel
    }
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)

    $result = $form.ShowDialog()

    if ($result -eq [Windows.Forms.DialogResult]::OK) {
        $date = $calendar.SelectionStart
        $formatteddate = Get-Date $date -Format u
        return $formatteddate
    }
}

$meetingstext = ""
if($meetings){
    $usePrevious = Read-host -Prompt "Would you like to use the previous results? y or n"
    if($usePrevious -eq "y"){
        foreach($meeting in $meetings.value){
            if($meeting.showAs -ne "free"){
                if($meeting.location.displayname -like "Room*"){
                    if ($meeting.attendees.count -gt 1){
                        Write-Host $meeting.subject"--" $meeting.location.displayName -ForegroundColor Yellow
                        $meetingstext += $meeting.subject+" -- "+$meeting.location.displayName+[Environment]::NewLine

                        $meetingstart = Get-Date $meeting.start.dateTime
                        $meetingend = Get-Date $meeting.end.dateTime
                        $meetingstart = (Get-Date $meetingstart).AddHours(-5)
                        $meetingend = (Get-Date $meetingend).AddHours(-5)
                        $meetingstart = Get-Date $meetingstart -Format g
                        $meetingend = Get-Date $meetingend -Format g
                        $meetingstartcheck = Get-Date $meetingstart -Format d
                        $meetingendcheck = Get-Date $meetingend -Format d
                        if($meetingstartcheck -eq $meetingendcheck){
                            $meetingend = Get-Date $meetingend -Format t
                        }
                        Write-Host $meetingstart '-' $meetingend -ForegroundColor Green
                        $meetingstext += $meetingstart+" - "+$meetingend+[Environment]::NewLine
                        $attendees = $meeting.attendees
                        foreach($attendee in $attendees){
                            if ($attendee.status.response -ne "declined")
                            {
                                Write-Host $attendee.emailAddress.address
                                $meetingstext += $attendee.emailAddress.address+[Environment]::NewLine
                            }
                        }

                        Write-Host ""
                        $meetingstext += [Environment]::NewLine
                    }
                }
            }
        }
        break
    }
}

#Ask for username
$user = Read-Host -Prompt "What username are you searching? Do not include domain"
$domain = "DOMAINHERE"

#Get current date and date two weeks ago
$enddate = SelectDate
$startdate = Get-Date $enddate
$startdate = $startdate.AddDays(-14)
$startdate = Get-Date $startdate -Format u
$enddate = $enddate.Replace(" ", "T")
$startdate = $startdate.Replace(" ", "T")

#fill out Graph string
$graphstring = "https://graph.microsoft.com/v1.0/users/$user@$domain/calendarview/delta?startdatetime=$startdate&enddatetime=$enddate"

#Link to Graph site
$needGraphlink = Read-host -Prompt "Do you need the link to Microsoft Graph? y or n"
if($needGraphlink -eq "y"){
    Set-Clipboard "https://developer.microsoft.com/en-us/graph/graph-explorer#"
    Write-Host "Please paste the following URL: https://developer.microsoft.com/en-us/graph/graph-explorer#"
    Write-Host "(It should already be in your clipboard)"
    Start-Sleep -s 5
    Write-Host ""
    Read-Host -Prompt "Press Enter to continue once you have the website loaded"
}

#String to paste in Graph
Set-Clipboard $graphstring
Write-Host "Please paste the following string into the box to the left of the 'Run query' button:"
Write-Host $graphstring -ForegroundColor Green
Write-Host "(It should already be in your clipboard)"
Start-Sleep -s 5
Write-Host ""
Read-Host -Prompt "Press Enter to continue once you have the data copied to your clipboard"

#Get meeting info
$meetings = Get-Clipboard -Raw | ConvertFrom-Json
#$meetings = Get-Content -Raw -Path C:\Users\$env:UserName\Desktop\meetings.json | ConvertFrom-Json
#Provide meeting names, location and accepted invites
#echo $meetings.value.attendees.emailAddress.name
foreach($meeting in $meetings.value){
    if($meeting.showAs -ne "free"){
        if($meeting.location.displayname -like "Room*"){
            if ($meeting.attendees.count -gt 1){
                Write-Host $meeting.subject"--" $meeting.location.displayName -ForegroundColor Yellow
                $meetingstext += $meeting.subject+" -- "+$meeting.location.displayName+[Environment]::NewLine

                $meetingstart = Get-Date $meeting.start.dateTime
                $meetingend = Get-Date $meeting.end.dateTime
                $meetingstart = (Get-Date $meetingstart).AddHours(-5)
                $meetingend = (Get-Date $meetingend).AddHours(-5)
                $meetingstart = Get-Date $meetingstart -Format g
                $meetingend = Get-Date $meetingend -Format g
                $meetingstartcheck = Get-Date $meetingstart -Format d
                $meetingendcheck = Get-Date $meetingend -Format d
                if($meetingstartcheck -eq $meetingendcheck){
                    $meetingend = Get-Date $meetingend -Format t
                }
                Write-Host $meetingstart '-' $meetingend -ForegroundColor Green
                $meetingstext += $meetingstart+" - "+$meetingend+[Environment]::NewLine
                $attendees = $meeting.attendees
                foreach($attendee in $attendees){
                    if ($attendee.status.response -ne "declined")
                    {
                        Write-Host $attendee.emailAddress.address
                        $meetingstext += $attendee.emailAddress.address+[Environment]::NewLine
                    }
                }

                Write-Host ""
                $meetingstext += [Environment]::NewLine
            }
        }
    }
}
#Use below if you want to copy to clipboard
#Set-Clipboard $meetingstext
