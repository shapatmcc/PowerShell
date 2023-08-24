#Description: This divides a list from a file into multiple lists/files. The files are named by weekdays. It also deletes files with a future date before starting the process, to avoid duplicates. 
$FolderPath = "FILEPATHHERE\*.csv
 # Remove files with a future date
$today = Get-Date
Get-ChildItem -Path $FolderPath | ForEach-Object {
    $fileDate = $_.BaseName -replace '^filename_(\d{4}-\d{2}-\d{2})$', '$1' | get-date -ErrorAction SilentlyContinue
    if (($fileDate) -and ($fileDate -gt $today)) {
        Remove-Item $_.FullName -Force
    }
}

# Import the CSV file and process data into multiple files
function Get-NextBusinessDay {
    param([DateTime]$date)

    $dayOfWeek = $date.DayOfWeek

    if ($dayOfWeek -eq 'Saturday') {
        $date = $date.AddDays(2)
    } elseif ($dayOfWeek -eq 'Friday') {
        $date = $date.AddDays(3)
    } else {
        $date = $date.AddDays(1)
    }

    return $date
}

$csvFilePath = "FILEPATH TO DIVIDE HERE"
$csvArray = (Import-Csv $csvFilePath -Header "machine").machine

$maxItemsPerFile = 26
$currentIndex = 0

$currentDate = (Get-Date).AddDays(1) # Start with tomorrow's date

while ($currentIndex -lt $csvArray.Count) {
    $itemsToProcess = $csvArray[$currentIndex..($currentIndex + $maxItemsPerFile - 1)]
    $outputFileName = "awacs_upgrade_" + $currentDate.ToString("yyyy-MM-dd") + ".csv"

    $itemsToProcess | out-file \\Export\Path\Here\$outputFileName

    # Move to the next business day
    $currentDate = Get-NextBusinessDay -date $currentDate
    $currentIndex += $maxItemsPerFile
}
