<#
.SYNOPSIS
    Modified version of OSDPad with added support for Azure Blob Storage.
.DESCRIPTION
    This custom and opinionated version of OSDPad is used in combination with the Azure PowerShell Modules. (Az.Accounts, Az.Storage)
    
    It features the following changes compared to the original OSDPad by @SeguraOSD
        - Support for Azure Storage Accounts (UseAzStorage Switch)
        - Shows .md files in the Textbox even when Scripts are hidden
        - Hides the filename extension of scripts

    Original Version of OSDPad: https://github.com/OSDeploy/OSD/blob/master/Public/OSDPad/Start-OSDPad.ps1
.NOTES
    Must be used together with custom version of OSDPad.ps1 copied to the OSD Module directory. (overwrite original OSDPad.ps1)
    User must be logged in to Azure, e.g. by using `Connect-AzAccount -UseDeviceAuthentication`
.EXAMPLE
    Start-LCOSDPad -UseAzStorage -Hide 'Script' -Brand 'Leuchter IT Solutions AG' -Color '#e5352c' -FilterBlobNames "Start-OSDCloud.ps1"
    Starts OSDPad with Scripts hidden and a custom Brand name and color. The Script "Start-OSDCloud.ps1" is filtered out and is not shown.
#>

function Start-LCOSDPad {
    [CmdletBinding(DefaultParameterSetName = 'Standalone')]
    param (
        [Parameter(ParameterSetName = 'GitHub', Mandatory = $true, Position = 0)]
        [Alias('Owner', 'GitOwner')]
        [string]$RepoOwner,
        
        [Parameter(ParameterSetName = 'GitHub', Mandatory = $true, Position = 1)]
        [Parameter(ParameterSetName = 'GitLab', Mandatory = $true, Position = 0)]        
        [Alias('Repository', 'GitRepo')]
        [string]$RepoName,
        
        [Parameter(ParameterSetName = 'GitHub', Position = 2)]
        [Parameter(ParameterSetName = 'GitLab', Position = 1)]
        [Alias('GitPath', 'Folder')]
        [string]$RepoFolder,
        
        [Parameter(ParameterSetName = 'GitLab', Mandatory = $true)]
        [Alias('GitLabUri')]
        [string]$RepoDomain,

        [Parameter(ParameterSetName = 'GitHub')]
        [Parameter(ParameterSetName = 'GitLab')]
        [Alias('OAuthToken')]
        [string]$OAuth,

        [Parameter(ParameterSetName = 'AzStorage')]
        [switch]$UseAzStorage,

        [Parameter(ParameterSetName = 'AzStorage')]
        [string[]]$FilterBlobNames,

        [Alias('BrandingTitle')]
        [string]$Brand = 'Leuchter IT OSDCloud',
        [Alias('BrandingColor')]
        [string]$Color = '#01786A',
        
        [ValidateSet('Branding', 'Script')]
        [string[]]$Hide
    )
    #================================================
    #   Branding
    #================================================
    $Global:OSDPadBranding = $null
    $Global:OSDPadBranding = @{
        Title = $Brand
        Color = $Color
    }
    #================================================
    #   GitHub
    #================================================
    if ($PSCmdlet.ParameterSetName -eq 'GitHub') {
        $RepoType = 'GitHub'
        $Uri = "https://api.github.com/repos/$RepoOwner/$RepoName/contents/$RepoFolder"
        Write-Host -ForegroundColor DarkCyan $Uri

        if ($OAuth) {
            $Params = @{
                Headers         = @{Authorization = "Bearer $OAuth" }
                Method          = 'GET'
                Uri             = $Uri
                UseBasicParsing = $true
            }
        }
        else {
            $GitHubApiRateLimit = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/rate_limit' -Method Get
            Write-Host -ForegroundColor DarkGray "You have used $($GitHubApiRateLimit.rate.used) of your $($GitHubApiRateLimit.rate.limit) GitHub API Requests"
            Write-Host -ForegroundColor DarkGray 'You can create an OAuth Token at https://github.com/settings/tokens'
            Write-Host -ForegroundColor DarkGray 'Use the OAuth parameter to enable OSDPad Child-Item support'
            $Params = @{
                Method          = 'GET'
                Uri             = $Uri
                UseBasicParsing = $true
            }
        }

        $GitHubApiContent = @()
        try {
            $GitHubApiContent = Invoke-RestMethod @Params -ErrorAction Stop
        }
        catch {
            Write-Warning $_
            Break
        }      
        
        if ($OAuth) {
            foreach ($Item in $GitHubApiContent) {
                if ($Item.type -eq 'dir') {
                    Write-Host -ForegroundColor DarkCyan $Item.url
                    $GitHubApiContent += Invoke-RestMethod -UseBasicParsing -Uri $Item.url -Method Get -Headers @{Authorization = "Bearer $OAuth" }
                }
            }
        }

        #$GitHubApiContent = $GitHubApiContent | Where-Object {$_.type -eq 'file'} | Where-Object {($_.name -match 'README.md') -or ($_.name -like "*.ps1")}
        $GitHubApiContent = $GitHubApiContent | Where-Object { ($_.type -eq 'dir') -or ($_.name -like '*.md') -or ($_.name -like '*.ps1') }

        Write-Host -ForegroundColor DarkGray '========================================================================='
        $Results = foreach ($Item in $GitHubApiContent) {
            #$FileContent = Invoke-RestMethod -UseBasicParsing -Uri $Item.git_url
            if ($Item.type -eq 'dir') {
                Write-Host -ForegroundColor DarkCyan "Directory: Start-OSDPad $RepoOwner $RepoName $($Item.name)"
                
                $ObjectProperties = @{
                    RepoOwner  = $RepoOwner
                    RepoName   = $RepoName
                    RepoFolder = $RepoFolder
                    Name       = $Item.name
                    Type       = $Item.type
                    Guid       = New-Guid
                    Path       = $Item.path
                    Size       = $Item.size
                    SHA        = $Item.sha
                    Git        = $Item.git_url
                    Download   = $Item.download_url
                    ContentRAW = $null
                    #NodeId         = $FileContent.node_id
                    #Content        = $FileContent.content
                    #Encoding       = $FileContent.encoding
                }
                #New-Object -TypeName PSObject -Property $ObjectProperties
            }
            else {
                Write-Host -ForegroundColor DarkGray $Item.download_url
                try {
                    $ScriptWebRequest = Invoke-WebRequest -Uri $Item.download_url -UseBasicParsing -ErrorAction Ignore
                }
                catch {
                    Write-Warning $_
                    $ScriptWebRequest = $null
                    Continue
                }
        
                $ObjectProperties = @{
                    RepoType   = $RepoType
                    RepoOwner  = $RepoOwner
                    RepoName   = $RepoName
                    RepoFolder = $RepoFolder
                    Name       = $Item.name
                    Type       = $Item.type
                    Guid       = New-Guid
                    Path       = $Item.path
                    Size       = $Item.size
                    SHA        = $Item.sha
                    Git        = $Item.git_url
                    Download   = $Item.download_url
                    ContentRAW = $ScriptWebRequest.Content
                    #NodeId         = $FileContent.node_id
                    #Content        = $FileContent.content
                    #Encoding       = $FileContent.encoding
                }
                New-Object -TypeName PSObject -Property $ObjectProperties
            }
        }
        $Global:OSDPad = $Results
        
    }
    #================================================
    #   GitLab
    #================================================
    elseif ($PSCmdlet.ParameterSetName -eq 'GitLab') {        
        $RepoType = 'GitLab'
        $RestAPI = "api/v4/projects/$RepoName/repository/tree?path=$RepoFolder&recursive=true"
        $Uri = "https://$RepoDomain/$RestAPI"       
        Write-Host -ForegroundColor DarkCyan $Uri
        
        $Params = @{
            Method          = 'GET'
            Uri             = $Uri
            UseBasicParsing = $true
        }
        IF ($OAuth) { 
            $Params.add('Headers', @{'PRIVATE-TOKEN' = "$OAuth" }) 
        }  
        
        $GitLabApiContent = @()
        try {
            $GitLabApiContent = Invoke-RestMethod @Params -ErrorAction Stop
        }
        catch {
            Write-Warning $_
            Break
        }      

        $GitLabApiContent = $GitLabApiContent | Where-Object { ($_.name -like '*.md') -or ($_.name -like '*.ps1') }
        
        Write-Host -ForegroundColor DarkGray '========================================================================='
        $Results = foreach ($Item in $GitLabApiContent) {
            #$FileContent = Invoke-RestMethod -UseBasicParsing -Uri $Item.git_url
            if ($Item.type -eq 'tree') {
                Write-Host -ForegroundColor DarkCyan "Directory: Start-OSDPad $RepoDomain $RepoName $($Item.name)"
                
                $ObjectProperties = @{
                    RepoOwner  = $RepoOwner
                    RepoName   = $RepoName
                    RepoFolder = $RepoFolder
                    Name       = $Item.name
                    Type       = $Item.type
                    Guid       = New-Guid
                    Path       = $Item.path
                    Size       = $Item.size
                    SHA        = $Item.sha
                    Git        = $Item.git_url
                    Download   = $Item.download_url
                    ContentRAW = $null
                    #NodeId         = $FileContent.node_id
                    #Content        = $FileContent.content
                    #Encoding       = $FileContent.encoding
                }
                #New-Object -TypeName PSObject -Property $ObjectProperties
            }
            else {
                $filePath = [System.Web.HttpUtility]::UrlEncode($Item.path)
                $RestAPI = "api/v4/projects/$RepoName/repository/files/$filePath/raw?ref=main"
                $Uri = "https://$RepoDomain/$RestAPI"
                Write-Host -ForegroundColor DarkGray $Uri
                
                $Params = @{
                    Method          = 'GET'
                    Uri             = $Uri
                    UseBasicParsing = $true
                }
                IF ($OAuth) { 
                    $Params.add('Headers', @{'PRIVATE-TOKEN' = "$OAuth" }) 
                }                

                try {
                    $ScriptWebRequest = Invoke-RestMethod @Params -ErrorAction Ignore
                }
                catch {
                    Write-Warning $_
                    $ScriptWebRequest = $null
                    Continue
                }
        
                $ObjectProperties = @{
                    RepoType   = $RepoType
                    RepoDomain = $RepoDomain
                    #RepoOwner  = $RepoOwner
                    RepoName   = $RepoName
                    RepoFolder = $RepoFolder
                    Name       = $Item.name
                    Type       = $Item.type
                    Guid       = $Item.id
                    Path       = $Item.path
                    #Size       = $Item.size
                    #SHA        = $Item.sha
                    #Git        = $Item.git_url
                    #Download   = $Item.download_url
                    ContentRAW = $ScriptWebRequest
                    #NodeId         = $FileContent.node_id
                    #Content        = $FileContent.content
                    #Encoding       = $FileContent.encoding
                }
                New-Object -TypeName PSObject -Property $ObjectProperties
            }
        }
        $Global:OSDPad = $Results
    }
    #================================================
    #   AzStorage
    #================================================
    elseif ($PSCmdlet.ParameterSetName -eq 'AzStorage') {
        # Connect to AzureAD Tennant
        if (-NOT ($Global:AzureAD -or $Global:MgGraph)) {
            Connect-OSDCloudAzure
        }

        # Get OSDCloud Scripts from Azure Storage Account with OSDScripts Tag
        if (-NOT $($Global:AzOSDCloudBlobScript)) {
            Get-AzLCOSDCloudScript
        }

        Write-Host -ForegroundColor DarkGray '========================================================================='

        if ($Global:AzOSDCloudBlobScript) {
            $i = $null
            $Results = foreach ($Item in $Global:AzOSDCloudBlobScript) {

                if ($FilterBlobNames -contains $Item.Name) { continue }

                $i++
                
                $BlobClient = $Global:AzOSDCloudStorageAccounts | Where-Object { $_.StorageAccountName -eq $Item.BlobClient.AccountName }

                $ObjectProperties = @{
                    Number         = $i
                    Name           = $Item.Name
                    Path           = "$($Item.BlobClient.BlobContainerName)/$($Item.Name)"
                    Guid           = New-Guid
                    StorageAccount = $Item.BlobClient.AccountName
                    Tag            = ($BlobClient | Select-Object -ExpandProperty Tags).Get_Item('OSDScripts')
                    Container      = $Item.BlobClient.BlobContainerName
                    Blob           = $Item.Name
                    Location       = $BlobClient | Select-Object -ExpandProperty Location
                    ResourceGroup  = $BlobClient | Select-Object -ExpandProperty ResourceGroupName
                    Download       = $Item.BlobClient.Uri
                    ContentHash    = $Item.BlobProperties.ContentHash
                    ContentRAW     = $Item.ICloudBlob.DownloadText()
                    LastModified   = $Item.ICloudBlob.Properties.LastModified
                    
                }
                New-Object -TypeName PSObject -Property $ObjectProperties
            }

            $Results | Select-Object -Property Number, StorageAccount, Tag, Container, Blob, Location, ResourceGroup, URL | Format-Table #| Out-Host

            $Global:OSDPad = $Results
            Write-Host -ForegroundColor DarkGray '========================================================================='
            Write-Host -ForegroundColor Green 'Start-LCOSDPad'
            Write-Host -ForegroundColor DarkGray '========================================================================='

        }
        else {
            Write-Warning 'Unable to find scripts on any of the OSDScripts Azure Storage Containers'
            Write-Warning 'Make sure you have a scripts file or unattened in the OSDScripts Azure Storage Container'
            Write-Warning 'Make sure this user has the Azure Storage Blob Data Reader role to the OSDCloud Container'
            Write-Warning 'You may need to execute Get-AzOSDCloudBScript'
        }


    }
    else {
        $Global:OSDPad = $null
    }
    #================================================
    #   OSDPad.ps1
    #================================================
    & (Join-Path (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase 'Projects\OSDPad.ps1')

    #================================================
}