param(
  [string]$PodmanExe = 'C:\Users\CM\AppData\Local\Programs\Podman\podman.exe',
  [string]$ZapImage = 'docker.io/zaproxy/zap-stable:2.16.0',
  [string]$ComposeNetwork = 'fullstack-fastapi-benchmark_default',
  [string]$BackendContainer = 'fullstack-fastapi-benchmark-backend-1',
  [string]$ScannerBaseRoot = 'http://fullstack-fastapi-benchmark-backend-1:8000',
  [string]$ApiBasePath = '/api/v1',
  [string]$Username = 'admin@example.com',
  [string]$Password = 'changethis'
)

$ErrorActionPreference = 'Stop'

$outDir = 'C:\Java Developer\DAST\benchmarks\fullstack-fastapi-template\out\t3'
$rawSpec = Join-Path $outDir 'fullstack-fastapi-openapi-raw.json'
$sanitizedSpec = Join-Path $outDir 'fullstack-fastapi-openapi-sanitized.json'
$configPath = Join-Path $outDir 'automation.yaml'
$reportPath = Join-Path $outDir 'zap-report.json'
$logPath = Join-Path $outDir 'zap-run.log'
$summaryPath = Join-Path $outDir 'summary.md'
$metricsPath = Join-Path $outDir 'metrics.json'
$tokenPath = Join-Path $outDir 'token.json'
$healthUrl = "$ScannerBaseRoot$ApiBasePath/utils/health-check/"
$apiDocsUrl = "$ScannerBaseRoot$ApiBasePath/openapi.json"
$loginUrl = "$ScannerBaseRoot$ApiBasePath/login/access-token"
$protectedValidationUrl = "$ScannerBaseRoot$ApiBasePath/users/me"
$scannerTargetUrl = "$ScannerBaseRoot$ApiBasePath"
$docsUrl = "$ScannerBaseRoot/docs"
$requestSeeds = @(
  [PSCustomObject]@{ Url = "$scannerTargetUrl/login/test-token"; Method = 'POST' },
  [PSCustomObject]@{ Url = "$scannerTargetUrl/users/me"; Method = 'GET' },
  [PSCustomObject]@{ Url = "$scannerTargetUrl/users/?skip=0&limit=10"; Method = 'GET' },
  [PSCustomObject]@{ Url = "$scannerTargetUrl/items/?skip=0&limit=10"; Method = 'GET' }
)
$containerName = 'fullstack-fastapi-t3-zap'

function Remove-PodmanObject {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  & $PodmanExe @Args *> $null
}

function Invoke-BackendPython {
  param([string]$Script, [string[]]$Args)
  $output = & $PodmanExe exec $BackendContainer python -c $Script @Args 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw (($output -join "`n").Trim())
  }
  return ($output -join "`n")
}

function Invoke-NetworkFetch {
  param([string]$Url)
  $escapedUrl = $Url.Replace("'", "''")
  $script = "import urllib.request;url=r'$escapedUrl';response=urllib.request.urlopen(url);print(response.read().decode(),end='')"
  return Invoke-BackendPython -Script $script -Args @()
}

function Invoke-NetworkLogin {
  param([string]$Url, [string]$User, [string]$Pass)
  $escapedUrl = $Url.Replace("'", "''")
  $escapedUser = $User.Replace("'", "''")
  $escapedPass = $Pass.Replace("'", "''")
  $script = "import urllib.request,urllib.parse;url=r'$escapedUrl';user=r'$escapedUser';password=r'$escapedPass';data=urllib.parse.urlencode({'username':user,'password':password}).encode();req=urllib.request.Request(url,data=data,headers={'Content-Type':'application/x-www-form-urlencoded'});response=urllib.request.urlopen(req);print(response.read().decode(),end='')"
  return Invoke-BackendPython -Script $script -Args @()
}

function Invoke-NetworkProtectedStatus {
  param([string]$Url, [string]$AuthHeader)
  $escapedUrl = $Url.Replace("'", "''")
  $escapedAuth = $AuthHeader.Replace("'", "''")
  $script = "import urllib.request;url=r'$escapedUrl';auth=r'$escapedAuth';req=urllib.request.Request(url,headers={'Authorization':auth});response=urllib.request.urlopen(req);print(response.status,end='')"
  return Invoke-BackendPython -Script $script -Args @()
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
    - name: "fullstack-fastapi-t3"
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
      context: "fullstack-fastapi-t3"
$($requestorBlocks -join "`n")
  - type: spider
    parameters:
      context: "fullstack-fastapi-t3"
      url: "$docsUrl"
      maxDuration: 2
      maxDepth: 5
      maxChildren: 20
  - type: passiveScan-wait
    parameters:
      maxDuration: 2
  - type: activeScan
    parameters:
      context: "fullstack-fastapi-t3"
      maxRuleDurationInMins: 5
      maxScanDurationInMins: 12
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
  $output = & $PodmanExe run --rm --name $containerName --network $ComposeNetwork -v "${configPath}:/zap/wrk/config.yaml:Z" -v "${rawSpec}:/zap/wrk/fullstack-fastapi-openapi-raw.json:Z" -v "${sanitizedSpec}:/zap/wrk/fullstack-fastapi-openapi-sanitized.json:Z" -v "${outDir}:/zap/wrk:Z" $ZapImage zap.sh -cmd -autorun /zap/wrk/config.yaml 2>&1
  return [PSCustomObject]@{
    Output = $output
    ExitCode = $LASTEXITCODE
  }
}

New-Item -ItemType Directory -Force $outDir | Out-Null
Get-ChildItem $outDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

$healthBody = Invoke-NetworkFetch $healthUrl
$healthStatus = '200'
if (-not $healthBody) {
  throw "Health check returned no body from $healthUrl"
}

$rawContent = Invoke-NetworkFetch $apiDocsUrl
if (-not $rawContent) {
  throw "Failed to fetch API docs from $apiDocsUrl"
}
$rawContent | Set-Content $rawSpec

$tokenResponse = Invoke-NetworkLogin -Url $loginUrl -User $Username -Pass $Password
if (-not $tokenResponse) {
  throw "Login bootstrap returned no response"
}
$tokenResponse | Set-Content $tokenPath
$tokenData = $tokenResponse | ConvertFrom-Json
if (-not $tokenData.access_token) {
  throw "Login bootstrap did not return an access token"
}
$authHeader = "Bearer $($tokenData.access_token)"

$protectedStatus = (Invoke-NetworkProtectedStatus -Url $protectedValidationUrl -AuthHeader $authHeader).Trim()
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
  '# full-stack-fastapi-template T3 Summary',
  '',
  "- Health check: HTTP $healthStatus (network-side fetch)",
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
