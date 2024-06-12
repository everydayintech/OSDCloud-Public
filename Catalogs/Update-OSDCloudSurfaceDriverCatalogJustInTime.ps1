function Update-OSDCloudSurfaceDriverCatalogJustInTime {   
    [CmdletBinding()]
    param (
        [switch]$UpdateDriverPacksJson,
        [string[]]$ForceUpdateProducts
    )

    $ProgressPreference = 'SilentlyContinue'

    function Get-NewDownloadCenterDriverPack {
        param (
            $DriverPack,
            [switch]$UpdateDriverPacksJson
        )
        
        try {
            Write-Verbose "Download Center URL: $($DriverPack.DownloadCenter)"
            $DownloadCenter = Invoke-WebRequest -Uri $DriverPack.DownloadCenter -UseBasicParsing | Select-Object -ExpandProperty Content

            $DriverOsVersion = $DriverPack.Url -match '_(Win[\d]{2})_' | ForEach-Object { $Matches[1] }
            $MsiDownloadsMatch = [regex]::Matches($DownloadCenter, '"url":"(https:[\w\-\/\.]+\.msi)"')
            $UpdatedDriverUrl = ($MsiDownloadsMatch | Where-Object { $_.Value -match $DriverOsVersion }).Groups[1].Value
            $UpdateDriverFilename = $UpdatedDriverUrl.Split('/') | Select-Object -Last 1

            #Replace download links in CloudDriverPacks.json
            if ($UpdateDriverPacksJson) {
                $content = [System.IO.File]::ReadAllText($Script:LocalCloudDriverPacksJson)

                Write-Verbose "Replacing [$($DriverPack.Url)] with [$($UpdatedDriverUrl)]"
                $content = $content.Replace($DriverPack.Url, $UpdatedDriverUrl)

                Write-Verbose "Replacing [$($DriverPack.FileName)] with [$($UpdateDriverFilename)]"
                $content = $content.Replace($DriverPack.FileName, $UpdateDriverFilename)

                [System.IO.File]::WriteAllText($Script:LocalCloudDriverPacksJson, $content)
                
                Write-Host "Updated download URL to: $($UpdatedDriverUrl)"
            }
            else {
                Write-Host "New download URL: $($UpdatedDriverUrl)"
            }
        }
        catch {
            Write-Warning 'Unable to retrieve updated download URL'
        }

    }

    $OSDModuleBase = (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase
    $Script:LocalCloudDriverPacksJson = (Join-Path $OSDModuleBase 'Catalogs\CloudDriverPacks.json')
    $LocalMicrosoftDriverPacksJson = (Join-Path $OSDModuleBase 'Catalogs\MicrosoftDriverPackCatalog.json')

    $Catalog = Get-Content -Encoding UTF8 -Raw -Path $LocalMicrosoftDriverPacksJson | ConvertFrom-Json

    foreach ($DriverPack in $Catalog) {
        $Updated = $false
        try {
            $Response = Invoke-WebRequest -Method Head -Uri $DriverPack.Url -UseBasicParsing -ErrorAction Stop
            Write-Verbose ('{0} {1}' -f $Response.StatusCode, $DriverPack.Url)
        }
        catch [System.Net.WebException] {
            $Err = $_
            Write-Warning "DriverPack for $($DriverPack.Name) ($($DriverPack.Product)) is not available at $($DriverPack.Url)"
            Write-Verbose $Err.Exception.Message

            $Updated = $true
            Get-NewDownloadCenterDriverPack -DriverPack $DriverPack -UpdateDriverPacksJson:$UpdateDriverPacksJson
        }
        catch {
            $Err = $_
            Write-Warning "$($Err.Exception.Message) [$($Err.Exception.GetType().FullName)]"
        }

        if(($ForceUpdateProducts -contains $DriverPack.Product) -and (-NOT $Updated)) {
            Write-Host "Forcing update for $($DriverPack.Product)"
            Write-Warning "Updating DriverPack for $($DriverPack.Name) ($($DriverPack.Product)) at $($DriverPack.Url)"
            Get-NewDownloadCenterDriverPack -DriverPack $DriverPack -UpdateDriverPacksJson:$UpdateDriverPacksJson
        }
    }
}