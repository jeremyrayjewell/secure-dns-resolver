Param(
  [Parameter(Mandatory=$false)]
  [string]$RepoRoot,

  [Parameter(Mandatory=$false)]
  [string]$OpenSslExe,

  # Validity periods
  [Parameter(Mandatory=$false)]
  [int]$CaDays = 3650,

  [Parameter(Mandatory=$false)]
  [int]$ServerDays = 825
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
  $RepoRoot = (Resolve-Path (Join-Path $scriptDir "..\")).Path
} else {
  $RepoRoot = (Resolve-Path $RepoRoot).Path
}

$certDir = Join-Path $RepoRoot "certs"
$cnfPath = Join-Path $RepoRoot "configs\tls\openssl-dot.cnf"

$caKey = Join-Path $certDir "ca.key"
$caPem = Join-Path $certDir "ca.pem"

$serverKey = Join-Path $certDir "server.key"
$serverCsr = Join-Path $certDir "server.csr"
$serverPem = Join-Path $certDir "server.pem"
$caSrl = Join-Path $certDir "ca.srl"

if (!(Test-Path $certDir)) { New-Item -ItemType Directory -Path $certDir | Out-Null }
if (!(Test-Path $cnfPath)) { throw "Missing OpenSSL config: $cnfPath" }

function Require-Command([string]$Name) {
  if (!(Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found in PATH: $Name. Install OpenSSL and ensure 'openssl' is available." 
  }
}

if ([string]::IsNullOrWhiteSpace($OpenSslExe)) {
  $cmd = Get-Command -Name "openssl" -ErrorAction SilentlyContinue
  if ($cmd) {
    $OpenSslExe = $cmd.Source
  } else {
    $candidates = @(
      "C:\\Program Files\\OpenSSL-Win64\\bin\\openssl.exe",
      "C:\\Program Files\\OpenSSL-Win32\\bin\\openssl.exe",
      "C:\\Program Files\\FireDaemon OpenSSL 3\\bin\\openssl.exe"
    )

    foreach ($candidate in $candidates) {
      if (Test-Path $candidate) {
        $OpenSslExe = $candidate
        break
      }
    }
  }
}

if ([string]::IsNullOrWhiteSpace($OpenSslExe) -or !(Test-Path $OpenSslExe)) {
  throw "OpenSSL not found. Install OpenSSL or re-run with -OpenSslExe <full\\path\\to\\openssl.exe>."
}

Write-Host "Generating CA and server certs in: $certDir"
Write-Host "Using OpenSSL config: $cnfPath"

# 1) Create a private CA (for client trust during lab testing)
if (!(Test-Path $caKey)) {
  & $OpenSslExe genrsa -out $caKey 4096
}
if (!(Test-Path $caPem)) {
  & $OpenSslExe req -x509 -new -nodes -key $caKey -sha256 -days $CaDays -subj "/CN=dot-lab-ca" -out $caPem
}

# 2) Create a leaf server keypair + CSR
& $OpenSslExe genrsa -out $serverKey 2048
& $OpenSslExe req -new -key $serverKey -out $serverCsr -config $cnfPath

# 3) Sign leaf cert with the lab CA, including SANs from openssl-dot.cnf
& $OpenSslExe x509 -req -in $serverCsr -CA $caPem -CAkey $caKey -CAcreateserial -out $serverPem -days $ServerDays -sha256 -extfile $cnfPath -extensions req_ext

Write-Host "Created:"
Write-Host " - $caPem (import this into client trust store for DoT validation)"
Write-Host " - $serverPem (configure as tls-service-pem)"
Write-Host " - $serverKey (configure as tls-service-key)"

Write-Host "Note: keep $caKey private. If it leaks, any certs it signs are untrusted."