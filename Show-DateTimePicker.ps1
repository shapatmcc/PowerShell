#Description: Modified datetime picker function. Not mine but I use it for other scripts in this repo
#DateTime Picker function
function Show-DateTimePicker {
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "DateTime Picker"
    $form.Size = New-Object System.Drawing.Size(250, 150)
    $form.FormBorderStyle = "FixedDialog"
    $form.StartPosition = "CenterScreen"

    $dateTimePicker = New-Object System.Windows.Forms.DateTimePicker
    $dateTimePicker.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
    $dateTimePicker.CustomFormat = "yyyy-MM-dd HH:mm:ss"
    $dateTimePicker.ShowUpDown = $true
    $dateTimePicker.Location = New-Object System.Drawing.Point(20, 20)
    $dateTimePicker.Size = New-Object System.Drawing.Size(200, 20)

    if((((Get-Date).AddDays(1)).DayOfWeek -eq "Saturday")){
        $defaultDateTime = (Get-Date).AddDays(3).Date.AddHours(9).AddMinutes(30)
    } else {
        $defaultDateTime = (Get-Date).AddDays(1).Date.AddHours(9).AddMinutes(30)
    }
    $dateTimePicker.Value = $defaultDateTime

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $okButton.Location = New-Object System.Drawing.Point(75, 70)
    $okButton.Size = New-Object System.Drawing.Size(75, 23)
    $okButton.Anchor = "Bottom"

    $form.AcceptButton = $okButton

    $form.Controls.Add($dateTimePicker)
    $form.Controls.Add($okButton)

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dateTimePicker.Value
    } else {
        return $null
    }
}
