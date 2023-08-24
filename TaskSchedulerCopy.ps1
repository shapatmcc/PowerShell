#Description: Grabs a task from Task Scheduler and copies it, modifying the parameters
#Pre-requisites: Need Show-FilePicker and Show-DateTimePicker files in the same folder

################
###Functions####
################

#File Picker
. .\Show-FilePicker.ps1
#Date Time Picker
. .\Show-DateTimePicker.ps1

Import-Module -Name ScheduledTasks

################
###Variables####
################

$taskname = "FILL IN HERE"
$newTaskTime = Show-DateTimePicker | Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
$Path = Show-FilePicker -FileType csv
$taskargumentfolder = $myinvocation.MyCommand.path | Split-Path -Parent


#########################
###Running the Script####
#########################

#import task if needed or load from task scheduler
if(!(Get-ScheduledTask -TaskName $taskname -ErrorAction SilentlyContinue)){
    $task = register-scheduledtask -Xml (get-content '..\task_template.xml' | out-string) -TaskName $taskname
} else {
    $task = Get-ScheduledTask -TaskName $taskname
}

#create new task and set task variables
$newTaskName = "TASK NAME $(Get-Date $newTaskTime -Format "yyyMMdd h")"
$newArguments = "-File $taskargumentfolder\YOUR POWERSHELL SCRIPT HERE.ps1 -Path $Path"
$newTask = $task | Select-Object -Property *
$newTask.TaskName = $newTaskName
$newTask.Settings.Enabled = $true
$newTask.Actions[0].Arguments = $newArguments
$newTask.Triggers[0].StartBoundary = $newTaskTime
$newTask.Principal.UserId = $env:USERNAME

#register new task
Register-ScheduledTask -TaskName $newTaskName -TaskPath $newTask.TaskPath -User $newTask.Author -Action $newTask.Actions -Trigger $newTask.Triggers -Settings $newTask.Settings
Read-Host "Press enter to exit"
