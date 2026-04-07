param(
    [Parameter(Mandatory = $true)]
    [string]$TargetRepoPath,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$templateRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$resolvedTarget = (Resolve-Path -LiteralPath $TargetRepoPath).Path

$workflowSource = Join-Path $templateRoot '.github\workflows'
$workflowTarget = Join-Path $resolvedTarget '.github\workflows'
$zerodastSource = Join-Path $templateRoot 'zerodast'
$zerodastTarget = Join-Path $resolvedTarget 'zerodast'

if (-not (Test-Path -LiteralPath (Join-Path $resolvedTarget '.git'))) {
    throw "Target path must be a git repository root: $resolvedTarget"
}

New-Item -ItemType Directory -Force -Path $workflowTarget | Out-Null

$workflowFiles = @(
    'zerodast-pr.yml',
    'zerodast-nightly.yml'
)

foreach ($file in $workflowFiles) {
    $destination = Join-Path $workflowTarget $file
    if ((Test-Path -LiteralPath $destination) -and -not $Force) {
        throw "Refusing to overwrite existing workflow without -Force: $destination"
    }
}

if ((Test-Path -LiteralPath $zerodastTarget) -and -not $Force) {
    throw "Refusing to overwrite existing zerodast directory without -Force: $zerodastTarget"
}

foreach ($file in $workflowFiles) {
    Copy-Item -LiteralPath (Join-Path $workflowSource $file) -Destination (Join-Path $workflowTarget $file) -Force
}

if (Test-Path -LiteralPath $zerodastTarget) {
    Remove-Item -LiteralPath $zerodastTarget -Recurse -Force
}

Copy-Item -LiteralPath $zerodastSource -Destination $zerodastTarget -Recurse -Force

Write-Host "ZeroDAST model-1 prototype installed into $resolvedTarget"
Write-Host "Added:"
Write-Host " - .github/workflows/zerodast-pr.yml"
Write-Host " - .github/workflows/zerodast-nightly.yml"
Write-Host " - zerodast/"
