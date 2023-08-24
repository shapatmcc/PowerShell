#Description: This uses Ipam's API to delete IPV6 records
 $cred = Get-Credential

[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

$OpenFIleDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.InitialDirectory = $InitialDirectory
$OpenFileDialog.Filter = "CSV (*.csv) | *.csv"

$OpenFileDialog.ShowDialog() | Out-Null
$Path = $OpenFileDialog.Filename

$entries = Import-Csv -Path $Path -Header 'Hostname','IP'
$entries = $entries | Where-Object -property IP -like "2620:*"
foreach($entry in $entries)
{
    $hostname = $entry.hostname
    $result = (Invoke-RestMethod -Method Get -Uri https://ipam.domain.net/wapi/v1.6/record:host?name=$hostname.domain.com -Credential $cred -skipcertificatecheck)._ref
    if($result.count -gt 1)
    {
        Write-Host "More than one result found for $hostname"
    }
    elseif(!$result)
    {
        Write-host "No results found for $hostname"
    }
    else
    {
        Invoke-RestMethod -Method Delete -Uri https://ipam.domain.net/wapi/v1.6/$result -Credential $cred -skipcertificatecheck
    }
}
