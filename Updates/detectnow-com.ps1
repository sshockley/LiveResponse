$autoUpdate = New-Object -ComObject Microsoft.Update.AutoUpdate
$autoUpdate.DetectNow()
(New-Object -com "Microsoft.Update.AutoUpdate").Settings
