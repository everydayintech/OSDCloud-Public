function Test-OSDCloudSurfaceDriverCatalog {
    <#
    .SYNOPSIS
        Verifies availability of all Surface Driver Packs
    .DESCRIPTION
        Verifies that all Surface Driver Packs are available for download in the MicrosoftDriverPackCatalog.json file
    .EXAMPLE
        Test-OSDCloudSurfaceDriverCatalog
    .EXAMPLE
        Test-OSDCloudSurfaceDriverCatalog -CatalogFileUrl 'https://raw.githubusercontent.com/OSDeploy/OSD/c527a9df96be7ffe8e738d8305918065b35f1a09/Catalogs/MicrosoftDriverPackCatalog.json'

    #>
    
    [CmdletBinding()]
    param (
        [string]$CatalogFileUrl = 'https://raw.githubusercontent.com/OSDeploy/OSD/master/Catalogs/MicrosoftDriverPackCatalog.json'
    )

    $AllDriverPacksAvailable = $true

    $Catalog = Invoke-RestMethod -Uri $CatalogFileUrl -UseBasicParsing

    foreach ($DriverPack in $Catalog) {
        try {
            $Response = Invoke-WebRequest -Method Head -Uri $DriverPack.Url -UseBasicParsing -ErrorAction Stop

            Write-Verbose ('{0} {1}' -f $Response.StatusCode, $DriverPack.Url)
        }
        catch {
            $Err = $_
            $AllDriverPacksAvailable = $false
            Write-Warning "DriverPack for $($DriverPack.Name) ($($DriverPack.Product)) is not available at $($DriverPack.Url)"
            Write-Verbose $Err.Exception.Message

            Write-Warning "Download Center URL: $($DriverPack.DownloadCenter)"
            try {
                $DownloadCenter = Invoke-WebRequest -Uri $DriverPack.DownloadCenter -UseBasicParsing | Select-Object -ExpandProperty Content
                $UpdatedOn = $DownloadCenter -match '"detailsSection_file_date":"([\/\d]+)"' | ForEach-Object { $Matches[1] }
                if (-NOT $UpdatedOn) { throw }
                Write-Warning "Download updated on: $UpdatedOn"
            }
            catch {
                Write-Warning 'Unable to retrieve Download Center last update date'
            }
        }
    }

    return $AllDriverPacksAvailable
}