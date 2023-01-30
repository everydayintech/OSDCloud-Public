Write-Host -ForegroundColor Cyan "Set keyboard language to de-CH"
Start-Sleep -Seconds 1

$LanguageList = Get-WinUserLanguageList

$LanguageList.Add("de-CH")
Set-WinUserLanguageList $LanguageList -Force

Start-Sleep -Seconds 2

$LanguageList = Get-WinUserLanguageList
$LanguageList.Remove(($LanguageList | Where-Object LanguageTag -like 'de-DE'))
Set-WinUserLanguageList $LanguageList -Force

$LanguageList = Get-WinUserLanguageList
$LanguageList.Remove(($LanguageList | Where-Object LanguageTag -like 'en-US'))
Set-WinUserLanguageList $LanguageList -Force