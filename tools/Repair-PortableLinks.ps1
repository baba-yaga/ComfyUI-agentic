[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ComfyRoot,

    [switch]$LegacyExperimentalNames
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$portableRoot = (Resolve-Path -LiteralPath $ComfyRoot).Path

if ($portableRoot -eq $repositoryRoot) {
    throw 'The portable ComfyUI root must be different from the repository root.'
}

foreach ($requiredPath in @('python_embeded\python.exe', 'ComfyUI\main.py', 'tools')) {
    if (-not (Test-Path -LiteralPath (Join-Path $portableRoot $requiredPath))) {
        throw "Not a portable ComfyUI root: $portableRoot (missing $requiredPath)"
    }
}

if (-not [string]::Equals(
        [IO.Path]::GetPathRoot($repositoryRoot),
        [IO.Path]::GetPathRoot($portableRoot),
        [StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'NTFS hard links require the repository and portable ComfyUI root to be on the same volume.'
}

$links = @(
    @{ Source = 'AGENTS.md'; Target = 'AGENTS.md' },
    @{ Source = 'run_comfyui_cdp.bat'; Target = 'run_comfyui_cdp.bat' },
    @{ Source = 'run_comfyui_cdp_server.bat'; Target = 'run_comfyui_cdp_server.bat' },
    @{ Source = 'tools\Invoke-CdpEvaluate.ps1'; Target = 'tools\Invoke-CdpEvaluate.ps1' },
    @{ Source = 'tools\comfy_chrome_mcp.py'; Target = 'tools\comfy_chrome_mcp.py' }
)

if ($LegacyExperimentalNames) {
    $links += @(
        @{ Source = 'run_comfyui_cdp.bat'; Target = 'run_comfyui_experimental_cdp.bat' },
        @{ Source = 'run_comfyui_cdp_server.bat'; Target = 'run_comfyui_experimental_cdp_server.bat' }
    )
}

foreach ($link in $links) {
    $sourcePath = Join-Path $repositoryRoot $link.Source
    $targetPath = Join-Path $portableRoot $link.Target
    $targetDirectory = Split-Path -Parent $targetPath

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing repository source file: $sourcePath"
    }
    if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
        throw "Missing portable target directory: $targetDirectory"
    }

    if ($PSCmdlet.ShouldProcess($targetPath, "replace with a hard link to $sourcePath")) {
        if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
            Remove-Item -LiteralPath $targetPath -Force
        } elseif (Test-Path -LiteralPath $targetPath) {
            throw "Refusing to replace a non-file target: $targetPath"
        }

        New-Item -ItemType HardLink -Path $targetPath -Target $sourcePath | Out-Null
        Write-Output "Linked $targetPath"
    }
}
