#Description: This looks for a file name based off of a particular format and the current date. If the file is found, it runs a script. 
#This can be handy when the script you want to run is dependant on the file that this script searches for. This script can be added to a scheduled task. 
 
 # Get today's date in the required format (YYYY_MM_dd)
$todayDate = Get-Date -Format "yyyy-MM-dd"

# Define the path to the folder where the file is located
$folderPath = "ENTER FOLDER PATH FOR FILE HERE"

# Construct the filename using today's date
$filename = "FILENAME HERE" + $todayDate + ".csv"

# Combine folder path and filename
$fullFilePath = Join-Path -Path $folderPath -ChildPath $filename

#Define the path to the folder where the script is located
$ScriptPath = "SCRIPT FOLDER PATH HERE"

#Define the file name of the script
$ScriptName = "SCRIPT FILENAME HERE"

# Check if the file exists in the folder
if (Test-Path $fullFilePath) {
    Start-Process powershell.exe -ArgumentList "-File $ScriptPath\$ScriptName -path $fullFilePath" -WorkingDirectory $ScriptPath
}
