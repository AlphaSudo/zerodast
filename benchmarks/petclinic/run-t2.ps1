param(
  [string]$PublicAppBaseUrl = 'http://127.0.0.1:9966/petclinic',
  [string]$ScannerBaseRoot = 'http://host.containers.internal:9966',
  [string]$ScannerBasePath = '/petclinic',
  [string]$PodmanExe = 'C:\Users\CM\AppData\Local\Programs\Podman\podman.exe',
  [string]$ZapImage = 'docker.io/zaproxy/zap-stable:2.16.0'
)

$ErrorActionPreference = 'Stop'

$outDir = 'C:\Java Developer\DAST\benchmarks\petclinic\out\t2'
$rawSpec = Join-Path $outDir 'petclinic-openapi-raw.json'
$sanitizedSpec = Join-Path $outDir 'petclinic-openapi-sanitized.json'
$configPath = Join-Path $outDir 'automation.yaml'
$reportPath = Join-Path $outDir 'zap-report.json'
$logPath = Join-Path $outDir 'zap-run.log'
$summaryPath = Join-Path $outDir 'summary.md'
$metricsPath = Join-Path $outDir 'metrics.json'
$apiDocsUrl = "$PublicAppBaseUrl/v3/api-docs"
$healthUrl = "$PublicAppBaseUrl/actuator/health"
$scannerPetclinicBase = "$ScannerBaseRoot$ScannerBasePath"
$scannerApiDocsFile = 'file:///zap/wrk/petclinic-openapi-sanitized.json'
$containerName = 'petclinic-t2-zap'

New-Item -ItemType Directory -Force $outDir | Out-Null
Get-ChildItem $outDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

$healthResponse = Invoke-WebRequest -UseBasicParsing $healthUrl
if ($healthResponse.StatusCode -ne 200) {
  throw "Petclinic health check failed: $($healthResponse.StatusCode)"
}

$rawContent = (Invoke-WebRequest -UseBasicParsing $apiDocsUrl).Content
$rawContent | Set-Content $rawSpec

$spec = $rawContent | ConvertFrom-Json -Depth 100
if ($spec.info -and $spec.info.license) {
  [void]$spec.info.license.PSObject.Properties.Remove('extensions')
}
$spec.openapi = '3.0.3'
$spec | ConvertTo-Json -Depth 100 -Compress | Set-Content $sanitizedSpec

@"
env:
  contexts:
    - name: "petclinic-t2"
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
      apiUrl: "$scannerApiDocsFile"
      targetUrl: "$ScannerBaseRoot"
      context: "petclinic-t2"
  - type: spider
    parameters:
      context: "petclinic-t2"
      url: "$scannerPetclinicBase"
      maxDuration: 1
  - type: passiveScan-wait
    parameters:
      maxDuration: 1
  - type: activeScan
    parameters:
      context: "petclinic-t2"
      maxRuleDurationInMins: 3
      maxScanDurationInMins: 10
      threadPerHost: 4
      delayInMs: 50
  - type: report
    parameters:
      template: "traditional-json"
      reportDir: "/zap/wrk"
      reportFile: "zap-report.json"
"@ | Set-Content $configPath

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$podmanOutput = & $PodmanExe run --rm --name $containerName --add-host host.containers.internal:host-gateway -v "${configPath}:/zap/wrk/config.yaml:Z" -v "${sanitizedSpec}:/zap/wrk/petclinic-openapi-sanitized.json:Z" -v "${outDir}:/zap/wrk:Z" $ZapImage zap.sh -cmd -autorun /zap/wrk/config.yaml 2>&1
$zapExit = $LASTEXITCODE
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
$apiUris = $allUris | Where-Object { $_ -like '*petclinic/api/*' } | Sort-Object -Unique

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
  '# Petclinic T2 Summary',
  '',
  "- Health check: HTTP $($healthResponse.StatusCode)",
  "- API docs fetched: $apiDocsUrl",
  "- ZAP image: $ZapImage",
  "- ZAP exit code: $zapExit",
  "- Cold run duration: $([Math]::Round($stopwatch.Elapsed.TotalSeconds, 1))s",
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
  healthStatus = $healthResponse.StatusCode
  apiDocsUrl = $apiDocsUrl
  zapImage = $ZapImage
  zapExitCode = $zapExit
  coldRunSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
  apiAlertUriCount = $apiUris.Count
  riskCounts = $riskCounts
  alerts = $groupedAlerts
}
$metrics | ConvertTo-Json -Depth 10 | Set-Content $metricsPath

Get-Content $summaryPath
exit 0
