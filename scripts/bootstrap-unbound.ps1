Param(
  [Parameter(Mandatory=$false)]
  [string]$RepoRoot,

  [Parameter(Mandatory=$false)]
  [string]$UnboundAnchorExe
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $scriptPath = $PSCommandPath
  if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    $scriptPath = $MyInvocation.MyCommand.Path
  }

  if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    throw "Cannot determine script location. Re-run with -RepoRoot <path>."
  }

  $scriptDir = Split-Path -Parent $scriptPath
  $RepoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
} else {
  $RepoRoot = (Resolve-Path $RepoRoot).Path
}

$varDir = Join-Path $RepoRoot "var"
$hintsPath = Join-Path $varDir "root.hints"
$rootKeyPath = Join-Path $varDir "root.key"

if ([string]::IsNullOrWhiteSpace($UnboundAnchorExe)) {
  $cmd = Get-Command -Name "unbound-anchor" -ErrorAction SilentlyContinue
  if ($cmd) {
    $UnboundAnchorExe = $cmd.Source
  } else {
    $candidates = @(
      (Join-Path $env:ProgramFiles "Unbound\unbound-anchor.exe"),
      (Join-Path ${env:ProgramFiles(x86)} "Unbound\unbound-anchor.exe"),
      (Join-Path $RepoRoot "bin\unbound-anchor.exe")
    )

    foreach ($candidate in $candidates) {
      if (![string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
        $UnboundAnchorExe = $candidate
        break
      }
    }
  }
}

if ([string]::IsNullOrWhiteSpace($UnboundAnchorExe) -or !(Test-Path $UnboundAnchorExe)) {
  throw "unbound-anchor not found. Install Unbound (NLnet Labs) and add its install directory to PATH, or re-run with -UnboundAnchorExe <full\\path\\to\\unbound-anchor.exe>."
}

Write-Host "Repo root: $RepoRoot"

if (!(Test-Path $varDir)) { New-Item -ItemType Directory -Path $varDir | Out-Null }

# 1) Fetch root hints from Internic
# Source: https://www.internic.net/domain/named.root
$rootHintsUrl = "https://www.internic.net/domain/named.root"
Write-Host "Downloading root hints from $rootHintsUrl -> $hintsPath"
Invoke-WebRequest -Uri $rootHintsUrl -UseBasicParsing -OutFile $hintsPath

# 2) Bootstrap DNSSEC root trust anchor state file using unbound-anchor
# Requires unbound-anchor.exe in PATH (from Unbound install).
Write-Host "Bootstrapping trust anchor -> $rootKeyPath"
& $UnboundAnchorExe -a $rootKeyPath

Write-Host "Done. Generated:"
Write-Host " - $hintsPath"
Write-Host " - $rootKeyPath"
