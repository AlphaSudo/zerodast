param(
    [Parameter(Mandatory = $true)]
    [string]$TargetRepoPath
)

$ErrorActionPreference = 'Stop'

$resolvedTarget = (Resolve-Path -LiteralPath $TargetRepoPath).Path

if (-not (Test-Path -LiteralPath (Join-Path $resolvedTarget '.git'))) {
    throw "Target path must be a git repository root: $resolvedTarget"
}

$workflowDir = Join-Path $resolvedTarget '.github\workflows'
$workflowFiles = @(
    (Join-Path $workflowDir 'zerodast-pr.yml'),
    (Join-Path $workflowDir 'zerodast-nightly.yml')
)

foreach ($path in $workflowFiles) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
    }
}

$zerodastTarget = Join-Path $resolvedTarget 'zerodast'
if (Test-Path -LiteralPath $zerodastTarget) {
    Remove-Item -LiteralPath $zerodastTarget -Recurse -Force
}

Write-Host "ZeroDAST model-1 prototype removed from $resolvedTarget"
