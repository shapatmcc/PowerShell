#Description: Modified file picker window. Not mine but I use it for other files in this repo
 #File picker window function
function Show-FilePicker {
param(
    [Parameter(Mandatory)] $FileType
    )
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $filterstring = "$($filetype.toupper()) (*.$filetype) | *.$filetype"
    $OpenFIleDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.InitialDirectory = $InitialDirectory
    $OpenFileDialog.Filter = $filterstring
    $OpenFIleDialog.Title = "Choose list of machine names to upgrade"
    $OpenFileDialog.ShowDialog() | Out-Null
    $chosenPath = $OpenFileDialog.Filename
    return $chosenPath
}
