function Update-OSDCloudSurfaceDriverCatalogJustInTime {   
    [CmdletBinding()]
    param (
        [switch]$UpdateDriverPacksJson
    )

    $ProgressPreference = 'SilentlyContinue'

    $LocalCloudDriverPacksJson = (Join-Path (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase 'Catalogs\CloudDriverPacks.json')
    $LocalMicrosoftDriverPacksJson = (Join-Path (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase 'Catalogs\MicrosoftDriverPackCatalog.json')

    $Catalog = Get-Content -Encoding UTF8 -Raw -Path $LocalMicrosoftDriverPacksJson | ConvertFrom-Json

    foreach ($DriverPack in $Catalog) {
        try {
            $Response = Invoke-WebRequest -Method Head -Uri $DriverPack.Url -UseBasicParsing -ErrorAction Stop

            Write-Verbose ('{0} {1}' -f $Response.StatusCode, $DriverPack.Url)
        }
        catch {
            $Err = $_
            Write-Warning "DriverPack for $($DriverPack.Name) ($($DriverPack.Product)) is not available at $($DriverPack.Url)"
            Write-Verbose $Err.Exception.Message

            Write-Warning "Download Center URL: $($DriverPack.DownloadCenter)"
            try {
                $DownloadCenter = Invoke-WebRequest -Uri $DriverPack.DownloadCenter -UseBasicParsing | Select-Object -ExpandProperty Content
                [datetime]$UpdatedOn = $DownloadCenter -match '"detailsSection_file_date":"([\/\d]+)"' | ForEach-Object { $Matches[1] }
                if (-NOT $UpdatedOn) { throw }
                Write-Warning "Download updated on: $($UpdatedOn.ToString('d'))"

                $DriverOsVersion = $DriverPack.Url -match '_(Win[\d]{2})_' | ForEach-Object { $Matches[1] }
                $MsiDownloadsMatch = [regex]::Matches($DownloadCenter, "`"url`":`"(https:[\w\-\/\.]+\.msi)`"")
                $UpdatedDriverUrl = ($MsiDownloadsMatch | Where-Object { $_.Value -match $DriverOsVersion }).Groups[1].Value
                
                Write-Host "New Download URL: $($UpdatedDriverUrl)"

                #Replace dead download links in CloudDriverPacks.json
                if ($UpdateDriverPacksJson) {
                    $content = [System.IO.File]::ReadAllText($LocalCloudDriverPacksJson).Replace($DriverPack.Url, $UpdatedDriverUrl)
                    [System.IO.File]::WriteAllText($LocalCloudDriverPacksJson, $content)
                }
                
                
            }
            catch {
                Write-Warning 'Unable to retrieve updated download URL'
            }
        }
    }
}