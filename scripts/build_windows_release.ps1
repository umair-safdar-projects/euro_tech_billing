param(
  [string]$Version = "1.0.1",
  [string]$BuildNumber = "2",
  [string]$SourceRevision = "local",
  [string]$PipelineRun = "local",
  [string]$Flutter = "flutter",
  [string]$InnoCompiler = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

function Invoke-Checked {
  param(
    [string]$FilePath,
    [string[]]$Arguments
  )
  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$FilePath failed with exit code $LASTEXITCODE"
  }
}

Write-Host "Building Euro Tech Billing $Version+$BuildNumber"
Invoke-Checked $Flutter @("pub", "get")
Invoke-Checked $Flutter @("analyze")
Invoke-Checked $Flutter @("test")
Invoke-Checked $Flutter @(
  "build", "windows", "--release",
  "--build-name", $Version,
  "--build-number", $BuildNumber,
  "--dart-define=APP_BUILD_SHA=$SourceRevision",
  "--dart-define=APP_BUILD_RUN=$PipelineRun"
)

$ReleaseDirectory = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$RequiredReleaseFiles = @(
  "EuroTechBilling.exe",
  "flutter_windows.dll",
  "data\app.so",
  "data\flutter_assets",
  "sqlite3.dll"
)
foreach ($ReleaseFile in $RequiredReleaseFiles) {
  $ReleasePath = Join-Path $ReleaseDirectory $ReleaseFile
  if (-not (Test-Path $ReleasePath)) {
    throw "Required Windows release component was not produced at $ReleasePath"
  }
}
if (-not (Test-Path $InnoCompiler)) {
  throw "Inno Setup 6 was not found. Install it or pass -InnoCompiler with the ISCC.exe path."
}

Invoke-Checked $InnoCompiler @("/DMyAppVersion=$Version", "installer\euro_tech_billing.iss")
Write-Host "Release and installer created successfully. See dist\."
