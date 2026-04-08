param(
  [string]$PodmanExe = 'C:\Users\CM\AppData\Local\Programs\Podman\podman.exe',
  [string]$ZapImage = 'docker.io/zaproxy/zap-stable:2.16.0',
  [string]$ComposeNetwork = 'fullstack-fastapi-benchmark_default',
  [string]$ScannerBaseRoot = 'http://fullstack-fastapi-benchmark-backend-1:8000',
  [string]$ApiBasePath = '/api/v1',
  [string]$Username = 'admin@example.com',
  [string]$Password = 'changethis'
)

$ErrorActionPreference = 'Stop'

$outDir = 'C:\Java Developer\DAST\benchmarks\fullstack-fastapi-template\out\t2'
$rawSpec = Join-Path $outDir 'fullstack-fastapi-openapi-raw.json'
$sanitizedSpec = Join-Path $outDir 'fullstack-fastapi-openapi-sanitized.json'
$configPath = Join-Path $outDir 'automation.yaml'
$reportPath = Join-Path $outDir 'zap-report.json'
$logPath = Join-Path $outDir 'zap-run.log'
$summaryPath = Join-Path $outDir 'summary.md'
$metricsPath = Join-Path $outDir 'metrics.json'
$tokenPath = Join-Path $outDir 'token.json'
$healthUrl = "http://localhost:8000$ApiBasePath/utils/health-check/"
$apiDocsUrl = "http://localhost:8000$ApiBasePath/openapi.json"
$loginUrl = "http://localhost:8000$ApiBasePath/login/access-token"
$protectedValidationUrl = "http://localhost:8000$ApiBasePath/users/me"
$scannerTargetUrl = "$ScannerBaseRoot$ApiBasePath"
$docsUrl = "$ScannerBaseRoot/docs"
$requestSeeds = @(
  [PSCustomObject]@{ Url = "$scannerTargetUrl/login/test-token"; Method = 'POST' },
  [PSCustomObject]@{ Url = "$scannerTargetUrl/users/me"; Method = 'GET' },
  [PSCustomObject]@{ Url = "$scannerTargetUrl/users/?skip=0&limit=10"; Method = 'GET' },
  [PSCustomObject]@{ Url = "$scannerTargetUrl/items/?skip=0&limit=10"; Method = 'GET' }
)
$containerName = 'fullstack-fastapi-t2-zap'

function Remove-PodmanObject {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  $stdoutPath = Join-Path $outDir 'podman-remove.stdout.log'
  $stderrPath = Join-Path $outDir 'podman-remove.stderr.log'
  $process = Start-Process -FilePath $PodmanExe -ArgumentList $Args -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
  Remove-Item $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
}

function Escape-YamlDoubleQuotedScalar {
  param([string]$Value)
  return ($Value -replace '\\', '\\\\' -replace '"', '\"')
}

function Write-AutomationConfig {
  param(
    [string]$ApiDocsFile,
    [string]$AuthHeader
  )

  $escapedAuthHeader = Escape-YamlDoubleQuotedScalar $AuthHeader
  $requestorBlocks = foreach ($seed in $requestSeeds) {
@"
  - type: requestor
    parameters:
      user: ""
    requests:
      - url: "$($seed.Url)"
        method: "$($seed.Method)"
"@
  }

@"
env:
  contexts:
    - name: "fullstack-fastapi-t2"
      urls:
        - "$scannerTargetUrl"
      includePaths:
        - "$scannerTargetUrl.*"
  parameters:
    failOnError: true
    progressToStdout: true
jobs:
  - type: replacer
    parameters:
      deleteAllRules: true
    rules:
      - description: "Auth token injection"
        matchType: "REQ_HEADER"
        matchString: "Authorization"
        replacementString: "$escapedAuthHeader"
  - type: openapi
    parameters:
      apiUrl: "$ApiDocsFile"
      targetUrl: "$ScannerBaseRoot"
      context: "fullstack-fastapi-t2"
$($requestorBlocks -join "`n")
  - type: spider
    parameters:
      context: "fullstack-fastapi-t2"
      url: "$docsUrl"
      maxDuration: 1
      maxDepth: 4
      maxChildren: 20
  - type: passiveScan-wait
    parameters:
      maxDuration: 1
  - type: activeScan
    parameters:
      context: "fullstack-fastapi-t2"
      maxRuleDurationInMins: 3
      maxScanDurationInMins: 8
      threadPerHost: 4
      delayInMs: 50
  - type: report
    parameters:
      template: "traditional-json"
      reportDir: "/zap/wrk"
      reportFile: "zap-report.json"
"@ | Set-Content $configPath
}

function Invoke-ZapRun {
  Remove-PodmanObject rm -f $containerName
  $args = @(
    'run',
    '--rm',
    '--name', $containerName,
    '--network', $ComposeNetwork,
    '-v', "${configPath}:/zap/wrk/config.yaml:Z",
    '-v', "${rawSpec}:/zap/wrk/fullstack-fastapi-openapi-raw.json:Z",
    '-v', "${sanitizedSpec}:/zap/wrk/fullstack-fastapi-openapi-sanitized.json:Z",
    '-v', "${outDir}:/zap/wrk:Z",
    $ZapImage,
    'zap.sh',
    '-cmd',
    '-autorun',
    '/zap/wrk/config.yaml'
  )
  $stdoutPath = Join-Path $outDir 'podman-zap.stdout.log'
  $stderrPath = Join-Path $outDir 'podman-zap.stderr.log'
  $process = Start-Process -FilePath $PodmanExe -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
  $stdout = if (Test-Path $stdoutPath) { Get-Content $stdoutPath } else { @() }
  $stderr = if (Test-Path $stderrPath) { Get-Content $stderrPath } else { @() }
  $output = @($stdout + $stderr)
  Remove-Item $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
  return [PSCustomObject]@{
    Output = $output
    ExitCode = $process.ExitCode
  }
}

New-Item -ItemType Directory -Force $outDir | Out-Null
Get-ChildItem $outDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

$healthResponse = Invoke-WebRequest -UseBasicParsing $healthUrl
$healthStatus = [string]$healthResponse.StatusCode
if ($healthStatus -ne '200') {
  throw "Health check failed at $healthUrl with status $healthStatus"
}

$rawContent = (Invoke-WebRequest -UseBasicParsing $apiDocsUrl).Content
if (-not $rawContent) {
  throw "Failed to fetch API docs from $apiDocsUrl"
}
$rawContent | Set-Content $rawSpec

$tokenResponse = Invoke-RestMethod -Method Post -Uri $loginUrl -ContentType 'application/x-www-form-urlencoded' -Body "username=$Username&password=$Password"
if (-not $tokenResponse) {
  throw "Login bootstrap returned no response"
}
$tokenResponse | ConvertTo-Json -Depth 10 | Set-Content $tokenPath
$tokenData = $tokenResponse
if (-not $tokenData.access_token) {
  throw "Login bootstrap did not return an access token"
}
$authHeader = "Bearer $($tokenData.access_token)"

$protectedResponse = Invoke-WebRequest -UseBasicParsing $protectedValidationUrl -Headers @{ Authorization = $authHeader }
$protectedStatus = [string]$protectedResponse.StatusCode
if ($protectedStatus -ne '200') {
  throw "Protected route validation failed with status $protectedStatus"
}

$spec = $rawContent | ConvertFrom-Json -Depth 100
$spec.openapi = '3.0.3'
if ($spec.info -and $spec.info.license) {
  [void]$spec.info.license.PSObject.Properties.Remove('identifier')
  [void]$spec.info.license.PSObject.Properties.Remove('extensions')
}
if ($spec.jsonSchemaDialect) {
  [void]$spec.PSObject.Properties.Remove('jsonSchemaDialect')
}
if ($spec.servers) {
  $spec.servers = @(@{ url = $ApiBasePath; description = 'Benchmark network target' })
}
$spec | ConvertTo-Json -Depth 100 -Compress | Set-Content $sanitizedSpec

$specMode = 'raw'
$scannerApiDocsFile = 'file:///zap/wrk/fullstack-fastapi-openapi-raw.json'

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-AutomationConfig -ApiDocsFile $scannerApiDocsFile -AuthHeader $authHeader
$zapRun = Invoke-ZapRun
$podmanOutput = $zapRun.Output
$zapExit = $zapRun.ExitCode

if ((-not (Test-Path $reportPath)) -or (($podmanOutput -join "`n") -match 'Failed to import OpenAPI definition|OpenAPI')) {
  $specMode = 'sanitized'
  $scannerApiDocsFile = 'file:///zap/wrk/fullstack-fastapi-openapi-sanitized.json'
  Write-AutomationConfig -ApiDocsFile $scannerApiDocsFile -AuthHeader $authHeader
  $zapRun = Invoke-ZapRun
  $podmanOutput = $zapRun.Output
  $zapExit = $zapRun.ExitCode
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
$apiUris = $allUris | Where-Object { $_ -like '*fullstack-fastapi-benchmark-backend-1:8000/api/v1/*' } | Sort-Object -Unique

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
  '# full-stack-fastapi-template T2 Summary',
  '',
  "- Health check: HTTP $healthStatus",
  "- API docs fetched: $apiDocsUrl",
  "- Login bootstrap: success ($($tokenData.token_type), token length $($tokenData.access_token.Length))",
  "- Protected route validation: HTTP $protectedStatus on $protectedValidationUrl",
  "- Spec mode used: $specMode",
  "- ZAP image: $ZapImage",
  "- ZAP exit code: $zapExit",
  "- Cold run duration: $([Math]::Round($stopwatch.Elapsed.TotalSeconds, 1))s",
  "- Authenticated request seeds configured: $($requestSeeds.Count)",
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
  healthStatus = [int]$healthStatus
  apiDocsUrl = $apiDocsUrl
  loginUrl = $loginUrl
  protectedValidationUrl = $protectedValidationUrl
  protectedValidationStatus = [int]$protectedStatus
  specMode = $specMode
  zapImage = $ZapImage
  zapExitCode = $zapExit
  coldRunSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
  authTokenLength = $tokenData.access_token.Length
  authenticatedSeedCount = $requestSeeds.Count
  apiAlertUriCount = $apiUris.Count
  riskCounts = $riskCounts
  alerts = $groupedAlerts
}
$metrics | ConvertTo-Json -Depth 10 | Set-Content $metricsPath

Get-Content $summaryPath
exit 0
