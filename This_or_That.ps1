#Description: This allows you to choose between two scripts. In my example, it was to run a script now, or to schedule the same script for later
 $absolutePath = $myinvocation.MyCommand.path | Split-Path -Parent
. .\Scripts\Show-FilePicker.ps1


function Show-UpgradeDialog {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

    #Create a new form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Script Execution"
    $form.Size = New-Object System.Drawing.Size(300, 150)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle

    #Create labels and buttons
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $label.Size = New-Object System.Drawing.Size(280, 20)
    $label.Text = "Choose an option to run the awacs upgrade:"
    $form.Controls.Add($label)

    $buttonNow = New-Object System.Windows.Forms.Button
    $buttonNow.location = New-Object System.Drawing.Point(10, 60)
    $buttonNow.Size = New-Object System.Drawing.Size(120, 30)
    $buttonNow.Text = "Run Now"
    $buttonNow.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonNow)

    $buttonLater = New-Object System.Windows.Forms.Button
    $buttonLater.location = New-Object System.Drawing.Point(160, 60)
    $buttonLater.Size = New-Object System.Drawing.Size(120, 30)
    $buttonLater.Text = "Run Later"
    $buttonLater.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonLater)

    #Show the form and handle the user's choice
    $result = $form.ShowDialog()

    #Call the appropriate script based on the user's choice
    if($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $chosenpath = Show-FilePicker -FileType csv
        Start-Process powershell.exe -ArgumentList "-File $absolutepath\Scripts\Run2016Upgrade.ps1 -path $chosenpath" -WorkingDirectory $absolutepath\Scripts
    } else {
        Start-Process powershell.exe -ArgumentList "-File $absolutepath\Scripts\2016UpgradeTaskScheduler.ps1" -WorkingDirectory $absolutepath\Scripts
    }
}

Show-UpgradeDialog
