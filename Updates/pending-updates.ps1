# https://gist.github.com/Grimthorr/44727ea8cf5d3df11cf7
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateupdateSearcher()
$Updates = @($UpdateSearcher.Search("IsHidden=0 and IsInstalled=0").Updates)
$Updates | Select-Object Title,IsHidden,IsMandatory,IsDownloaded,LastDeploymentChangeTime
