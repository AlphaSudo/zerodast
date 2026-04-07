param(
  [string]$HostPortBind = '127.0.0.1:9976:9966',
  [string]$PodmanExe = 'C:\Users\CM\AppData\Local\Programs\Podman\podman.exe',
  [string]$AppImage = 'docker.io/springcommunity/spring-petclinic-rest:latest',
  [string]$ZapImage = 'docker.io/zaproxy/zap-stable:2.16.0',
  [string]$HelperImage = 'docker.io/library/node:20-alpine'
)

$ErrorActionPreference = 'Stop'

$outDir = 'C:\Java Developer\DAST\benchmarks\petclinic\out\t3'
$rawSpec = Join-Path $outDir 'petclinic-openapi-raw.json'
$sanitizedSpec = Join-Path $outDir 'petclinic-openapi-sanitized.json'
$configPath = Join-Path $outDir 'automation.yaml'
$reportPath = Join-Path $outDir 'zap-report.json'
$logPath = Join-Path $outDir 'zap-run.log'
$summaryPath = Join-Path $outDir 'summary.md'
$metricsPath = Join-Path $outDir 'metrics.json'
$networkName = 'petclinic-t3-net'
$appContainer = 'petclinic-t3-app'
$zapContainer = 'petclinic-t3-zap'
$scannerBaseRoot = "http://${appContainer}:9966"
$scannerBasePath = '/petclinic'
$scannerBaseUrl = "$scannerBaseRoot$scannerBasePath"
$healthUrl = "$scannerBaseUrl/actuator/health"
$apiDocsUrl = "$scannerBaseUrl/v3/api-docs"
$scannerApiDocsFile = 'file:///zap/wrk/petclinic-openapi-sanitized.json'

function Remove-PodmanObject {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  & $PodmanExe @Args *> $null
}

function Invoke-NetworkFetch {
  param([string]$Url)
  & $PodmanExe run --rm --network $networkName $HelperImage node -e "fetch(process.argv[1]).then(async (response) => { const body = await response.text(); if (!response.ok) { console.error(body); process.exit(response.status || 1); } process.stdout.write(body); }).catch((error) => { console.error(error.stack || error.message); process.exit(1); });" $Url
}

function Wait-ForHealth {
  param([string]$Url, [int]$Attempts = 45)
  for ($i = 0; $i -lt $Attempts; $i++) {
    $body = Invoke-NetworkFetch $Url 2>$null
    if ($LASTEXITCODE -eq 0) {
      return [PSCustomObject]@{ StatusCode = 200; Body = $body }
    }
    Start-Sleep -Seconds 2
  }
  throw "Timed out waiting for healthy app at $Url"
}

try {
  New-Item -ItemType Directory -Force $outDir | Out-Null
  Get-ChildItem $outDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

  Remove-PodmanObject rm -f $zapContainer $appContainer
  Remove-PodmanObject network rm $networkName

  & $PodmanExe network create --internal $networkName *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to create Podman network $networkName"
  }

  & $PodmanExe run -d --rm --network $networkName --name $appContainer -p $HostPortBind $AppImage *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to start app container $appContainer"
  }

  $healthResponse = Wait-ForHealth -Url $healthUrl

  $rawContent = Invoke-NetworkFetch $apiDocsUrl
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to fetch API docs from $apiDocsUrl"
  }
  $rawContent | Set-Content $rawSpec

  $spec = $rawContent | ConvertFrom-Json -Depth 100
  if ($spec.info -and $spec.info.license) {
    [void]$spec.info.license.PSObject.Properties.Remove('extensions')
  }
  $spec.openapi = '3.0.3'
  $spec | ConvertTo-Json -Depth 100 -Compress | Set-Content $sanitizedSpec

  $sampleValues = @{
    ownerId = '1'
    petId = '1'
    vetId = '1'
    specialtyId = '1'
    petTypeId = '1'
    visitId = '1'
  }

  $requestUrls = New-Object System.Collections.Generic.List[string]
  foreach ($property in $spec.paths.PSObject.Properties) {
    $path = $property.Name
    $operations = $property.Value
    if (-not $operations.get) {
      continue
    }
    $resolvedPath = $path
    foreach ($paramMatch in ([regex]::Matches($path, '\{([^}]+)\}'))) {
      $paramName = $paramMatch.Groups[1].Value
      $sampleValue = if ($sampleValues.ContainsKey($paramName)) { $sampleValues[$paramName] } else { '1' }
      $resolvedPath = $resolvedPath.Replace("{$paramName}", $sampleValue)
    }
    $requestUrls.Add("$scannerBaseUrl$resolvedPath")
  }
  $requestUrls.Add("$scannerBaseUrl/api/owners?lastName=Davis")
  $requestUrls = $requestUrls | Sort-Object -Unique

  $requestBlocks = foreach ($requestUrl in $requestUrls) {
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

  $automationYaml = @"
env:
  contexts:
    - name: "petclinic-t3"
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
      apiUrl: "$scannerApiDocsFile"
      targetUrl: "$scannerBaseRoot"
      context: "petclinic-t3"
$requestSection
  - type: spider
    parameters:
      context: "petclinic-t3"
      url: "$scannerBaseUrl/swagger-ui/index.html"
      maxDuration: 2
      maxDepth: 5
      maxChildren: 50
  - type: passiveScan-wait
    parameters:
      maxDuration: 2
  - type: activeScan
    parameters:
      context: "petclinic-t3"
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
"@
  $automationYaml | Set-Content $configPath

  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  $podmanOutput = & $PodmanExe run --rm --name $zapContainer --network $networkName -v "${configPath}:/zap/wrk/config.yaml:Z" -v "${sanitizedSpec}:/zap/wrk/petclinic-openapi-sanitized.json:Z" -v "${outDir}:/zap/wrk:Z" $ZapImage zap.sh -cmd -autorun /zap/wrk/config.yaml 2>&1
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
    '# Petclinic T3 Summary',
    '',
    "- Health check: HTTP $($healthResponse.StatusCode)",
    "- API docs fetched: $apiDocsUrl",
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
  Remove-PodmanObject rm -f $zapContainer $appContainer
  Remove-PodmanObject network rm $networkName
}



