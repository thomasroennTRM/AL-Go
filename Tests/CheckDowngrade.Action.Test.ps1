Get-Module TestActionsHelper | Remove-Module -Force
Import-Module (Join-Path $PSScriptRoot 'TestActionsHelper.psm1')
$errorActionPreference = "Stop"; $ProgressPreference = "SilentlyContinue"; Set-StrictMode -Version 2.0

Describe "CheckDowngrade Action Tests" {
    BeforeAll {
        $actionName = "CheckDowngrade"
        $scriptRoot = Join-Path $PSScriptRoot "..\Actions\$actionName" -Resolve
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'actionScript', Justification = 'False positive.')]
        $actionScript = GetActionScript -scriptRoot $scriptRoot -scriptName "$actionName.ps1"
        Invoke-Expression $actionScript

        function DownloadAndImportBcContainerHelper {}
        function New-BcAuthContext {}
        function Get-BcInstalledExtensions {}
        function Get-AppJsonFromAppFile {}
    }

    BeforeEach {
        $env:Secrets = '{"Sandbox-AuthContext":"e30="}'
        Mock DownloadAndImportBcContainerHelper {}
        Mock New-BcAuthContext { @{ tenantId = 'tenant' } }
        Mock Get-BcInstalledExtensions { @() }
        Mock Get-AppJsonFromAppFile {
            @{
                id = '00000000-0000-0000-0000-000000000001'
                name = 'Test App'
                version = '1.0.0.0'
            }
        }
    }

    It 'Compile Action' {
        Invoke-Expression $actionScript
    }

    It 'Test action.yaml matches script' {
        $outputs = [ordered]@{}
        YamlTest -scriptRoot $scriptRoot -actionName $actionName -actionScript $actionScript -outputs $outputs
    }

    It 'Does not initialize dependencies when disabled' {
        CheckDowngrade -environmentName 'Sandbox' -artifactsFolder 'missing'

        Should -Invoke DownloadAndImportBcContainerHelper -Times 0
    }

    It 'Fails when an artifact version is lower than the installed version' {
        $artifactsFolder = Join-Path $TestDrive 'project-Apps-1.0.0.0'
        New-Item -Path $artifactsFolder -ItemType Directory | Out-Null
        New-Item -Path (Join-Path $artifactsFolder 'Test.app') -ItemType File | Out-Null
        Mock Get-BcInstalledExtensions {
            @{
                id = '00000000-0000-0000-0000-000000000001'
                isInstalled = $true
                versionMajor = 2
                versionMinor = 0
                versionBuild = 0
                versionRevision = 0
            }
        }

        { CheckDowngrade -environmentName 'Sandbox' -artifactsFolder $artifactsFolder -failOnAppVersionDowngrade $true } |
            Should -Throw "Downgrade check failed:*"
    }

    It 'Passes when the artifact version is not lower than the installed version' {
        $artifactsFolder = Join-Path $TestDrive 'project-Apps-2.0.0.0'
        New-Item -Path $artifactsFolder -ItemType Directory | Out-Null
        New-Item -Path (Join-Path $artifactsFolder 'Test.app') -ItemType File | Out-Null
        Mock Get-AppJsonFromAppFile {
            @{
                id = '00000000-0000-0000-0000-000000000001'
                name = 'Test App'
                version = '2.0.0.0'
            }
        }
        Mock Get-BcInstalledExtensions {
            @{
                id = '00000000-0000-0000-0000-000000000001'
                isInstalled = $true
                versionMajor = 1
                versionMinor = 0
                versionBuild = 0
                versionRevision = 0
            }
        }

        { CheckDowngrade -environmentName 'Sandbox' -artifactsFolder $artifactsFolder -failOnAppVersionDowngrade $true } |
            Should -Not -Throw
    }
}
