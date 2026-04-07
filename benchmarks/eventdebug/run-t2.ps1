param(
  [string]$PodmanExe = 'C:\Users\CM\AppData\Local\Programs\Podman\podman.exe',
  [string]$ZapImage = 'docker.io/zaproxy/zap-stable:2.16.0',
  [string]$HelperImage = 'docker.io/library/node:20-alpine',
  [string]$ComposeNetwork = 'eventdebug-benchmark_default',
  [string]$ScannerBaseRoot = 'http://eventlens-app:9090',
  [string]$ScannerBasePath = '/api/v1'
)

$ErrorActionPreference = 'Stop'

$outDir = 'C:\Java Developer\DAST\benchmarks\eventdebug\out\t2'
$rawSpec = Join-Path $outDir 'eventdebug-openapi-raw.json'
$sanitizedSpec = Join-Path $outDir 'eventdebug-openapi-sanitized.json'
$configPath = Join-Path $outDir 'automation.yaml'
$reportPath = Join-Path $outDir 'zap-report.json'
$logPath = Join-Path $outDir 'zap-run.log'
$summaryPath = Join-Path $outDir 'summary.md'
$metricsPath = Join-Path $outDir 'metrics.json'
$healthUrl = "$ScannerBaseRoot$ScannerBasePath/health/ready"
$apiDocsUrl = "$ScannerBaseRoot$ScannerBasePath/openapi.json"
$containerName = 'eventdebug-t2-zap'

function Invoke-NetworkFetch {
  param([string]$Url)
  & $PodmanExe run --rm --network $ComposeNetwork $HelperImage node -e "fetch(process.argv[1]).then(async (response) => { const body = await response.text(); if (!response.ok) { console.error(body); process.exit(response.status || 1); } process.stdout.write(body); }).catch((error) => { console.error(error.stack || error.message); process.exit(1); });" $Url
}

function Remove-PodmanObject {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  & $PodmanExe @Args *> $null
}

function Write-AutomationConfig {
  param([string]$ApiDocsFile, [string[]]$RequestUrls)

  $requestBlocks = foreach ($requestUrl in $RequestUrls) {
    @(
      '      - url: "' + $requestUrl + '"'
      '        method: "GET"'
    ) -join "`n"
  }

  $requestSection = if ($requestBlocks.Count -gt 0) {
    "  - type: requestor`n    requests:`n" + ($requestBlocks -join "`n")
  } else {
    ''
  }

@"
env:
  contexts:
    - name: "eventdebug-t2"
      urls:
        - "$ScannerBaseRoot"
      includePaths:
        - "$ScannerBaseRoot$ScannerBasePath.*"
  parameters:
    failOnError: true
    progressToStdout: true
jobs:
  - type: openapi
    parameters:
      apiUrl: "$ApiDocsFile"
      targetUrl: "$ScannerBaseRoot"
      context: "eventdebug-t2"
$requestSection
  - type: spider
    parameters:
      context: "eventdebug-t2"
      url: "$ScannerBaseRoot$ScannerBasePath/openapi.json"
      maxDuration: 1
  - type: passiveScan-wait
    parameters:
      maxDuration: 1
  - type: activeScan
    parameters:
      context: "eventdebug-t2"
      maxRuleDurationInMins: 4
      maxScanDurationInMins: 12
      threadPerHost: 4
      delayInMs: 50
    policyDefinition:
      defaultStrength: medium
      defaultThreshold: low
  - type: report
    parameters:
      template: "traditional-json"
      reportDir: "/zap/wrk"
      reportFile: "zap-report.json"
"@ | Set-Content $configPath
}

function Invoke-ZapRun {
  Remove-PodmanObject rm -f $containerName
  & $PodmanExe run --rm --name $containerName --network $ComposeNetwork -v "${configPath}:/zap/wrk/config.yaml:Z" -v "${rawSpec}:/zap/wrk/eventdebug-openapi-raw.json:Z" -v "${sanitizedSpec}:/zap/wrk/eventdebug-openapi-sanitized.json:Z" -v "${outDir}:/zap/wrk:Z" $ZapImage zap.sh -cmd -autorun /zap/wrk/config.yaml 2>&1
  return $LASTEXITCODE
}

New-Item -ItemType Directory -Force $outDir | Out-Null
Get-ChildItem $outDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

$healthBody = Invoke-NetworkFetch $healthUrl 2>$null
if ($LASTEXITCODE -ne 0) {
  throw "EventDebug health check failed at $healthUrl"
}

$rawContent = Invoke-NetworkFetch $apiDocsUrl
if ($LASTEXITCODE -ne 0) {
  throw "Failed to fetch API docs from $apiDocsUrl"
}
$rawContent | Set-Content $rawSpec

$spec = $rawContent | ConvertFrom-Json -Depth 100
$spec.openapi = '3.0.3'
if ($spec.info -and $spec.info.license) {
  [void]$spec.info.license.PSObject.Properties.Remove('extensions')
}
if ($spec.servers) {
  $spec.servers = @(@{ url = $ScannerBasePath; description = 'Benchmark network target' })
}
$spec | ConvertTo-Json -Depth 100 -Compress | Set-Content $sanitizedSpec

$requestUrls = @(
  "$ScannerBaseRoot$ScannerBasePath/events/recent?limit=10",
  "$ScannerBaseRoot$ScannerBasePath/aggregates/search?q=ORD&limit=10",
  "$ScannerBaseRoot$ScannerBasePath/aggregates/search?q=ACC&limit=10",
  "$ScannerBaseRoot$ScannerBasePath/aggregates/ORD-001/timeline?limit=10",
  "$ScannerBaseRoot$ScannerBasePath/aggregates/ACC-002/timeline?limit=10"
) | Sort-Object -Unique

$specMode = 'raw'
$scannerApiDocsFile = 'file:///zap/wrk/eventdebug-openapi-raw.json'
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-AutomationConfig -ApiDocsFile $scannerApiDocsFile -RequestUrls $requestUrls
$podmanOutput = Invoke-ZapRun
$zapExit = $LASTEXITCODE

if ((-not (Test-Path $reportPath)) -or (($podmanOutput -join "`n") -match 'Failed to import OpenAPI definition|OpenAPI')) {
  $specMode = 'sanitized'
  $scannerApiDocsFile = 'file:///zap/wrk/eventdebug-openapi-sanitized.json'
  Write-AutomationConfig -ApiDocsFile $scannerApiDocsFile -RequestUrls $requestUrls
  $podmanOutput = Invoke-ZapRun
  $zapExit = $LASTEXITCODE
}
$stopwatch.Stop()
$podmanOutput | Set-Content $logPath

if (-not (Test-Path $reportPath)) {
  throw "ZAP did not generate a report at $reportPath"
}

$report = Get-Content $reportPath -Raw | ConvertFrom-Json -Depth 100
$alerts = foreach ($site in $report.site) {
  foreach ($alert in $site.alerts) {
    [PSCustomObject]@{
      Alert = $alert.alert
      RiskCode = [int]$alert.riskcode
      Count = [int]$alert.count
    }
  }
}

$groupedAlerts = $alerts |
  Group-Object Alert |
  ForEach-Object {
    [PSCustomObject]@{
      Alert = $_.Name
      RiskCode = ($_.Group | Select-Object -First 1).RiskCode
      Count = ($_.Group | Measure-Object -Property Count -Sum).Sum
    }
  } |
  Sort-Object -Property @{Expression='RiskCode';Descending=$true}, @{Expression='Alert';Descending=$false}

$allUris = foreach ($site in $report.site) {
  foreach ($alert in $site.alerts) {
    foreach ($instance in $alert.instances) {
      $instance.uri
    }
  }
}
$apiUris = $allUris | Where-Object { $_ -like '*eventlens-app:9090/api/v1/*' } | Sort-Object -Unique

$riskCounts = [ordered]@{
  critical = 0
  high = 0
  medium = 0
  low = 0
  informational = 0
}
foreach ($site in $report.site) {
  foreach ($alert in $site.alerts) {
    switch ([int]$alert.riskcode) {
      4 { $riskCounts.critical++ }
      3 { $riskCounts.high++ }
      2 { $riskCounts.medium++ }
      1 { $riskCounts.low++ }
      default { $riskCounts.informational++ }
    }
  }
}

$summaryLines = @(
  '# EventDebug T2 Summary',
  '',
  '- Health check: HTTP 200 (network-side fetch)',
  "- API docs fetched: $apiDocsUrl",
  "- Spec mode used: $specMode",
  "- ZAP image: $ZapImage",
  "- ZAP exit code: $zapExit",
  "- Cold run duration: $([Math]::Round($stopwatch.Elapsed.TotalSeconds, 1))s",
  "- Seeded request count: $($requestUrls.Count)",
  "- API alert URIs observed: $($apiUris.Count)",
  '',
  '## Risk Counts',
  '',
  '| Risk | Count |',
  '| --- | ---: |',
  "| Critical | $($riskCounts.critical) |",
  "| High | $($riskCounts.high) |",
  "| Medium | $($riskCounts.medium) |",
  "| Low | $($riskCounts.low) |",
  "| Informational | $($riskCounts.informational) |",
  '',
  '## Alerts',
  ''
)
foreach ($item in $groupedAlerts) {
  $summaryLines += "- $($item.Alert) (riskCode=$($item.RiskCode), count=$($item.Count))"
}
if ($apiUris.Count -gt 0) {
  $summaryLines += ''
  $summaryLines += '## API URIs with Alert Instances'
  $summaryLines += ''
  foreach ($uri in $apiUris) {
    $summaryLines += "- $uri"
  }
}
$summaryLines | Set-Content $summaryPath

$metrics = [PSCustomObject]@{
  healthStatus = 200
  apiDocsUrl = $apiDocsUrl
  specMode = $specMode
  zapImage = $ZapImage
  zapExitCode = $zapExit
  coldRunSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
  seededRequestCount = $requestUrls.Count
  apiAlertUriCount = $apiUris.Count
  riskCounts = $riskCounts
  alerts = $groupedAlerts
}
$metrics | ConvertTo-Json -Depth 10 | Set-Content $metricsPath

Get-Content $summaryPath
exit 0
