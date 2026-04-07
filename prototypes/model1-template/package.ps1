param(
    [string]$OutputRoot = "",
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$templateRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$defaultOutputRoot = Join-Path $templateRoot 'dist'
$resolvedOutputRoot = if ([string]::IsNullOrWhiteSpace($OutputRoot)) { $defaultOutputRoot } else { $OutputRoot }
$resolvedOutputRoot = [System.IO.Path]::GetFullPath($resolvedOutputRoot)
$kitRoot = Join-Path $resolvedOutputRoot 'model1-kit'
$zipPath = Join-Path $resolvedOutputRoot 'model1-kit.zip'
$repoRoot = Split-Path -Parent (Split-Path -Parent $templateRoot)

if ((Test-Path -LiteralPath $kitRoot) -and -not $Force) {
    throw "Refusing to overwrite existing kit directory without -Force: $kitRoot"
}

if ((Test-Path -LiteralPath $zipPath) -and -not $Force) {
    throw "Refusing to overwrite existing kit archive without -Force: $zipPath"
}

New-Item -ItemType Directory -Force -Path $resolvedOutputRoot | Out-Null

if (Test-Path -LiteralPath $kitRoot) {
    Remove-Item -LiteralPath $kitRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $kitRoot | Out-Null

$itemsToCopy = @(
    '.github',
    'zerodast',
    'install.ps1',
    'uninstall.ps1',
    'PROTOTYPE_GUIDE.md'
)

foreach ($item in $itemsToCopy) {
    Copy-Item -LiteralPath (Join-Path $templateRoot $item) -Destination (Join-Path $kitRoot $item) -Recurse -Force
}

$gitCommit = ''
try {
    $gitCommit = (git -C $repoRoot rev-parse --short HEAD).Trim()
} catch {
    $gitCommit = 'unknown'
}

$manifest = [ordered]@{
    name = 'zerodast-model1-kit'
    sourceCommit = $gitCommit
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    contents = @(
        '.github/workflows/zerodast-pr.yml',
        '.github/workflows/zerodast-nightly.yml',
        'zerodast/',
        'install.ps1',
        'uninstall.ps1',
        'PROTOTYPE_GUIDE.md'
    )
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $kitRoot 'manifest.json')

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path (Join-Path $kitRoot '*') -DestinationPath $zipPath -Force

Write-Host "Model 1 kit exported to $kitRoot"
Write-Host "Archive written to $zipPath"
