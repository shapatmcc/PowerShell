$webhookUrl = "webhookURL HERE"
$body = @{
    text = "Did you ever hear the tragedy of Darth Plageius the Wise?"
}
$jsonBody = $body | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri $webhookUrl -Body $jsonBody -ContentType 'application/json'
