param(
  [string]$PodmanExe = 'C:\Users\CM\AppData\Local\Programs\Podman\podman.exe',
  [string]$PostgresImage = 'docker.io/library/postgres:16-alpine',
  [string]$KafkaImage = 'docker.io/confluentinc/cp-kafka:7.7.0',
  [string]$AppImage = 'docker.io/library/eventdebug-benchmark-app:latest',
  [string]$ZapImage = 'docker.io/zaproxy/zap-stable:2.16.0',
  [string]$HelperImage = 'docker.io/library/node:20-alpine',
  [string]$BenchmarkClone = 'C:\Java Developer\eventdebug-benchmark'
)

$ErrorActionPreference = 'Stop'

$outDir = 'C:\Java Developer\DAST\benchmarks\eventdebug\out\t3'
$rawSpec = Join-Path $outDir 'eventdebug-openapi-raw.json'
$sanitizedSpec = Join-Path $outDir 'eventdebug-openapi-sanitized.json'
$configPath = Join-Path $outDir 'automation.yaml'
$reportPath = Join-Path $outDir 'zap-report.json'
$logPath = Join-Path $outDir 'zap-run.log'
$summaryPath = Join-Path $outDir 'summary.md'
$metricsPath = Join-Path $outDir 'metrics.json'
$networkName = 'eventdebug-t3-net'
$postgresContainer = 'eventdebug-t3-postgres'
$kafkaContainer = 'eventdebug-t3-kafka'
$appContainer = 'eventdebug-t3-app'
$zapContainer = 'eventdebug-t3-zap'
$scannerBaseRoot = "http://${appContainer}:9090"
$scannerBasePath = '/api/v1'
$healthUrl = "$scannerBaseRoot$scannerBasePath/health/ready"
$apiDocsUrl = "$scannerBaseRoot$scannerBasePath/openapi.json"
$seedSql = Join-Path $BenchmarkClone 'seed.sql'
$configSource = Join-Path $BenchmarkClone 'eventlens.yaml'

function Remove-PodmanObject {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  & $PodmanExe @Args *> $null
}

function Invoke-NetworkFetch {
  param([string]$Url)
  & $PodmanExe run --rm --network $networkName $HelperImage node -e "fetch(process.argv[1]).then(async (response) => { const body = await response.text(); if (!response.ok) { console.error(body); process.exit(response.status || 1); } process.stdout.write(body); }).catch((error) => { console.error(error.stack || error.message); process.exit(1); });" $Url
}

function Wait-ForContainerHealth {
  param([string]$ContainerName, [int]$Attempts = 45)
  for ($i = 0; $i -lt $Attempts; $i++) {
    $health = & $PodmanExe inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $ContainerName 2>$null
    if ($LASTEXITCODE -eq 0 -and ($health -eq 'healthy' -or $health -eq 'running')) {
      return $health
    }
    Start-Sleep -Seconds 2
  }
  throw "Timed out waiting for container health: $ContainerName"
}

function Wait-ForHealth {
  param([string]$Url, [int]$Attempts = 60)
  for ($i = 0; $i -lt $Attempts; $i++) {
    $body = Invoke-NetworkFetch $Url 2>$null
    if ($LASTEXITCODE -eq 0) {
      return [PSCustomObject]@{ StatusCode = 200; Body = $body }
    }
    Start-Sleep -Seconds 3
  }
  throw "Timed out waiting for healthy app at $Url"
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
    - name: "eventdebug-t3"
      urls:
        - "$scannerBaseRoot"
      includePaths:
        - "$scannerBaseRoot$scannerBasePath.*"
  parameters:
    failOnError: true
    progressToStdout: true
jobs:
  - type: openapi
    parameters:
      apiUrl: "$ApiDocsFile"
      targetUrl: "$scannerBaseRoot"
      context: "eventdebug-t3"
$requestSection
  - type: spider
    parameters:
      context: "eventdebug-t3"
      url: "$scannerBaseRoot$scannerBasePath/openapi.json"
      maxDuration: 2
      maxDepth: 5
      maxChildren: 20
  - type: passiveScan-wait
    parameters:
      maxDuration: 2
  - type: activeScan
    parameters:
      context: "eventdebug-t3"
      maxRuleDurationInMins: 5
      maxScanDurationInMins: 15
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
  Remove-PodmanObject rm -f $zapContainer
  & $PodmanExe run --rm --name $zapContainer --network $networkName -v "${configPath}:/zap/wrk/config.yaml:Z" -v "${rawSpec}:/zap/wrk/eventdebug-openapi-raw.json:Z" -v "${sanitizedSpec}:/zap/wrk/eventdebug-openapi-sanitized.json:Z" -v "${outDir}:/zap/wrk:Z" $ZapImage zap.sh -cmd -autorun /zap/wrk/config.yaml 2>&1
  return $LASTEXITCODE
}

try {
  New-Item -ItemType Directory -Force $outDir | Out-Null
  Get-ChildItem $outDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

  Remove-PodmanObject rm -f $zapContainer $appContainer $kafkaContainer $postgresContainer
  Remove-PodmanObject network rm $networkName

  & $PodmanExe network create --internal $networkName *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to create Podman network $networkName"
  }

  & $PodmanExe run -d --rm --network $networkName --network-alias postgres --name $postgresContainer `
    -e POSTGRES_DB=eventlens_dev -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=secret `
    -v "${seedSql}:/docker-entrypoint-initdb.d/seed.sql:Z" $PostgresImage *> $null
  if ($LASTEXITCODE -ne 0) {
    throw 'Failed to start T3 Postgres container'
  }

  & $PodmanExe run -d --rm --network $networkName --network-alias kafka --name $kafkaContainer `
    -e KAFKA_NODE_ID=1 `
    -e KAFKA_PROCESS_ROLES=broker,controller `
    -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093 `
    -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092 `
    -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER `
    -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT `
    -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafka:9093 `
    -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 `
    -e KAFKA_LOG_DIRS=/var/lib/kafka/data `
    -e CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk $KafkaImage *> $null
  if ($LASTEXITCODE -ne 0) {
    throw 'Failed to start T3 Kafka container'
  }

  Wait-ForContainerHealth -ContainerName $postgresContainer | Out-Null
  Wait-ForContainerHealth -ContainerName $kafkaContainer | Out-Null

  & $PodmanExe run -d --rm --network $networkName --network-alias eventlens-app --name $appContainer `
    -e EVENTLENS_CONFIG=/app/eventlens.yaml `
    -v "${configSource}:/app/eventlens.yaml:ro,Z" $AppImage *> $null
  if ($LASTEXITCODE -ne 0) {
    throw 'Failed to start T3 app container'
  }

  $healthResponse = Wait-ForHealth -Url $healthUrl

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
    $spec.servers = @(@{ url = $scannerBasePath; description = 'Isolated benchmark network target' })
  }
  $spec | ConvertTo-Json -Depth 100 -Compress | Set-Content $sanitizedSpec

  $requestUrls = @(
    "$scannerBaseRoot$scannerBasePath/events/recent?limit=10",
    "$scannerBaseRoot$scannerBasePath/aggregates/search?q=ORD&limit=10",
    "$scannerBaseRoot$scannerBasePath/aggregates/search?q=ACC&limit=10",
    "$scannerBaseRoot$scannerBasePath/aggregates/ORD-001/timeline?limit=10",
    "$scannerBaseRoot$scannerBasePath/aggregates/ACC-002/timeline?limit=10"
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
  $apiUris = $allUris | Where-Object { $_ -like '*eventdebug-t3-app:9090/api/v1/*' } | Sort-Object -Unique

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
    '# EventDebug T3 Summary',
    '',
    '- Health check: HTTP 200 (isolated network fetch)',
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
    healthStatus = $healthResponse.StatusCode
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
}
finally {
  Remove-PodmanObject rm -f $zapContainer $appContainer $kafkaContainer $postgresContainer
  Remove-PodmanObject network rm $networkName
}
