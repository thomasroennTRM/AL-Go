# Check downgrade

Checks whether app artifacts have lower versions than the corresponding apps installed in a Business Central environment.

## INPUT

### ENV variables

| Name | Required | Description |
| :-- | :-: | :-- |
| Secrets | Yes | JSON object containing the base64-encoded environment AuthContext secret |

### Parameters

| Name | Required | Description | Default value |
| :-- | :-: | :-- | :-- |
| shell | | The shell (powershell or pwsh) in which the PowerShell script in this action should run | powershell |
| environmentName | Yes | Name of environment to validate | |
| artifactsFolder | Yes | Path to the downloaded artifacts to validate | |
| failOnAppVersionDowngrade | | Fail when an artifact app version is lower than the installed version | false |

## OUTPUT

none