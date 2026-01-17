# Local development (secure secret injection)

This repo does not store any TLS private keys or certs.

Unbound expects its DoT TLS materials at:
- `/data/server.key`
- `/data/server.pem`

The container entrypoint writes those files from environment variables:
- `TLS_SERVER_KEY` (PEM private key)
- `TLS_SERVER_CERT` (PEM certificate)

## Option A: Run via Docker (recommended)

1) Generate certs locally (never commit):
- `powershell -ExecutionPolicy Bypass -File scripts/gen-dot-certs.ps1`

2) Export env vars in PowerShell:

```powershell
$env:TLS_SERVER_KEY  = Get-Content .\certs\server.key -Raw
$env:TLS_SERVER_CERT = Get-Content .\certs\server.pem -Raw
```

3) Run the container:

```powershell
docker build -t secure-dns-resolver:local .

# Allowlist networks for local testing (comma-separated). This is optional but
# usually required because the resolver is deny-by-default.
$env:UNBOUND_ALLOWED_NETS = "172.16.0.0/12,192.168.0.0/16"

docker run --rm \
  -p 8853:8853 \
  -p 8053:8053/udp \
  -p 8053:8053/tcp `
  -e TLS_SERVER_KEY="$env:TLS_SERVER_KEY" `
  -e TLS_SERVER_CERT="$env:TLS_SERVER_CERT" `
  -e UNBOUND_ALLOWED_NETS="$env:UNBOUND_ALLOWED_NETS" `
  secure-dns-resolver:local
```

Then test (example):
- `openssl s_client -connect 127.0.0.1:8853 -servername dot.local -CAfile certs/ca.pem`

## Option B: Run Unbound directly on the host

If you run Unbound without the container, you must still provide the key/cert at the same paths Unbound is configured to use.

On Windows, you can either:
- adjust your config paths to Windows locations, or
- run Unbound in WSL/Linux where `/data/...` paths are natural.

For Fly.io deployment, `/data` is used inside the container.
