[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserDataDir
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $UserDataDir -PathType Container)) {
    Write-Output 'No dedicated Chrome profile exists yet; there is no saved session to clear.'
    exit 0
}

$profileRoot = (Resolve-Path -LiteralPath $UserDataDir).Path
$chromeUsingProfile = Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe'" |
    Where-Object {
        $_.CommandLine -and
        $_.CommandLine.IndexOf($profileRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0
    }

if ($chromeUsingProfile) {
    throw "Refusing to change session files while Chrome is using $profileRoot."
}

$sessionPaths = @(
    (Join-Path $profileRoot 'Default\Sessions'),
    (Join-Path $profileRoot 'Default\Current Session'),
    (Join-Path $profileRoot 'Default\Current Tabs'),
    (Join-Path $profileRoot 'Default\Last Session'),
    (Join-Path $profileRoot 'Default\Last Tabs')
)

$removed = 0
foreach ($sessionPath in $sessionPaths) {
    if (Test-Path -LiteralPath $sessionPath) {
        if ($PSCmdlet.ShouldProcess($sessionPath, 'remove saved dedicated Chrome session state')) {
            Remove-Item -LiteralPath $sessionPath -Recurse -Force
            $removed++
        }
    }
}

if ($removed -eq 0) {
    Write-Output 'No saved dedicated Chrome session files were found.'
} else {
    Write-Output "Cleared $removed saved dedicated Chrome session item(s)."
}
