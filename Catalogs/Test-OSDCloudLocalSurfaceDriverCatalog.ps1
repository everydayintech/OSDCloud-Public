function Test-OSDCloudLocalSurfaceDriverCatalog {    
    
    [CmdletBinding()]
    param (
    )

    $ProgressPreference = 'SilentlyContinue'

    $AllDriverPacksAvailable = $true

    $OSDModuleBase = (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase
    $LocalCloudDriverPacksJson = (Join-Path $OSDModuleBase 'Catalogs\CloudDriverPacks.json')

    $Catalog = (Get-Content -Encoding UTF8 -Raw -Path $LocalCloudDriverPacksJson | ConvertFrom-Json) | Where-Object {$_.Manufacturer -eq "Microsoft"}

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
                [datetime]$UpdatedOn = $DownloadCenter -match '"detailsSection_file_date":"([\/\d]+)"' | ForEach-Object { $Matches[1] }
                if (-NOT $UpdatedOn) { throw }
                Write-Warning "Download updated on: $($UpdatedOn.ToString('d'))"
            }
            catch {
                Write-Warning 'Unable to retrieve Download Center last update date'
            }
        }
    }

    return $AllDriverPacksAvailable
}