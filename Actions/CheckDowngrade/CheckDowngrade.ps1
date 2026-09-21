Param(
    [Parameter(HelpMessage = "Name of environment to validate", Mandatory = $true)]
    [string] $environmentName,
    [Parameter(HelpMessage = "Path to the downloaded artifacts to validate", Mandatory = $true)]
    [string] $artifactsFolder,
    [Parameter(HelpMessage = "Fail when an artifact app version is lower than the installed version", Mandatory = $false)]
    [bool] $failOnAppVersionDowngrade = $false
)

$errorActionPreference = "Stop"; $ProgressPreference = "SilentlyContinue"; Set-StrictMode -Version 2.0

. (Join-Path -Path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)

if (-not $failOnAppVersionDowngrade) {
    Write-Host "Downgrade check is disabled."
    return
}

if (-not (Test-Path -Path $artifactsFolder -PathType Container)) {
    throw "Artifacts folder '$artifactsFolder' was not found."
}

DownloadAndImportBcContainerHelper

$envName = $environmentName.Split(' ')[0]
$secrets = $env:Secrets | ConvertFrom-Json
$authContext = $null
foreach ($secretName in "$($envName)-AuthContext", "$($envName)_AuthContext", "AuthContext") {
    if ($secrets."$secretName") {
        $authContext = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($secrets."$secretName"))
        Write-Host "::add-mask::$authContext"
        break
    }
}
if (-not $authContext) {
    throw "No Authentication Context found for environment ($environmentName)."
}

$authContextParams = $authContext | ConvertFrom-Json | ConvertTo-HashTable -recurse
$bcAuthContext = New-BcAuthContext @authContextParams
if ($null -eq $bcAuthContext) {
    throw "Authentication failed for environment '$environmentName'."
}

$appsToDeploy = @(Get-ChildItem -Path $artifactsFolder -Recurse -Filter *.app -File |
    Where-Object {
        $_.FullName -match '-Apps-' -and
        $_.FullName -notmatch '-TestApps-' -and
        $_.DirectoryName -notmatch '-Dependencies-'
    })

if (-not $appsToDeploy) {
    Write-Host "No app files found for downgrade validation in '$artifactsFolder'."
    return
}

$installedApps = Get-BcInstalledExtensions -bcAuthContext $bcAuthContext -environment $environmentName |
    Where-Object { $_.isInstalled }

$violations = @()
foreach ($appFile in $appsToDeploy) {
    $appJson = Get-AppJsonFromAppFile -appFile $appFile.FullName
    $installedApp = $installedApps | Where-Object { $_.id -eq $appJson.id }
    if (-not $installedApp) {
        continue
    }

    $artifactVersion = [version]::new($appJson.version)
    $installedVersion = [version]::new($installedApp.versionMajor, $installedApp.versionMinor, $installedApp.versionBuild, $installedApp.versionRevision)

    if ($artifactVersion -lt $installedVersion) {
        $violations += "App '$($appJson.name)' is already installed in version $installedVersion, which is higher than artifact version $artifactVersion."
    }
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object {
        Write-Host "::Error::$_"
    }
    throw "Downgrade check failed: one or more apps in the artifact are lower than installed versions in '$environmentName'."
}

Write-Host "Downgrade check passed for environment '$environmentName'."
