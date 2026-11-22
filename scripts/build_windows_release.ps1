param(
  [string]$Version = "1.0.0",
  [string]$BuildNumber = "1",
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
Invoke-Checked $Flutter @("build", "windows", "--release", "--build-name", $Version, "--build-number", $BuildNumber)

$Executable = Join-Path $ProjectRoot "build\windows\x64\runner\Release\EuroTechBilling.exe"
if (-not (Test-Path $Executable)) {
  throw "Windows release executable was not produced at $Executable"
}
if (-not (Test-Path $InnoCompiler)) {
  throw "Inno Setup 6 was not found. Install it or pass -InnoCompiler with the ISCC.exe path."
}

Invoke-Checked $InnoCompiler @("/DMyAppVersion=$Version", "installer\euro_tech_billing.iss")
Write-Host "Release and installer created successfully. See dist\."
