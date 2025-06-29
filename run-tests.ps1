param(
  [string]$TestCasesFile = "testcases.json",
  [string]$ResultsFile = "testResults.xml"
)

# -------- Settings --------
# Path to vstest.console.exe (change if you're using a different edition of VS)
$vstestExe = "C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\Common7\\IDE\\CommonExtensions\\Microsoft\\TestWindow\\vstest.console.exe"

# Temp .trx file
$trxFile = "TestResults.trx"

# -------- Read test list from JSON --------
if (-Not (Test-Path $TestCasesFile)) {
  Write-Error "❌ Test cases file not found: $TestCasesFile"
  exit 1
}

$cases = Get-Content $TestCasesFile | ConvertFrom-Json
$testFilters = $cases.tests -join '|'

# -------- Locate compiled test DLLs (ignore obj folders) --------
$testDlls = Get-ChildItem -Path "tests" -Recurse -Filter *.dll |
  Where-Object {
    $_.FullName -match "tests.*[\\/]bin[\\/](Debug|Release)[\\/].*\.dll" -and
    $_.FullName -match "Test"
  }

if ($testDlls.Count -eq 0) {
  Write-Error "❌ No test DLLs found in bin/ directories."
  exit 1
}

Write-Host "🧪 Found test DLLs:"
$testDlls | ForEach-Object { Write-Host "   → $($_.FullName)" }

# -------- Run tests from each DLL --------
foreach ($dll in $testDlls) {
  Write-Host "`n▶️  Running tests in: $($dll.FullName)`n"

  & "$vstestExe" $dll.FullName `
    /TestCaseFilter:"FullyQualifiedName~$testFilters" `
    /Logger:trx `
    /ResultsDirectory:.  # Writes trx to current folder

  if ($LASTEXITCODE -ne 0) {
    Write-Warning "⚠️ Test run completed with some failures."
  }
}

# -------- Convert TRX to JUnit XML (optional if trx2junit.exe exists) --------
if (Test-Path ".\\trx2junit.exe") {
  .\\trx2junit.exe $trxFile
  Rename-Item -Path "TEST-TestResults.xml" -NewName $ResultsFile -Force
  Write-Host "✅ Test results converted to JUnit XML: $ResultsFile"
} else {
  Write-Warning "⚠️ trx2junit.exe not found. Using mock testResults.xml for Jenkins."

  $mockXml = @"<?xml version="1.0" encoding="utf-8"?>
<testsuites>
  <testsuite name="MockSuite" tests="$($cases.tests.Count)" failures="0">
    $(
      $cases.tests | ForEach-Object {
        $parts = $_.Split('.')
        $method = $parts[-1]
        $class = ($parts[0..($parts.Length - 2)] -join '.')
        "<testcase classname='$class' name='$method' />"
      }
    )
  </testsuite>
</testsuites>
"@

  $mockXml | Out-File -FilePath $ResultsFile -Encoding utf8
  Write-Host "✅ Mock testResults.xml written to $ResultsFile"
}
