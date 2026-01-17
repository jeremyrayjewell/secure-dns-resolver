# Fly.io deployment (DoT over private WireGuard)

This deployment keeps the resolver **private-by-default**:
- Unbound listens for **DoT on TCP/853**.
- Access is allowed only from Fly's private IPv6 range (`fdaa::/8`) via WireGuard / 6PN.
- TLS key material is provided at runtime via Fly secrets (never stored in the repo).

## 0) Pre-reqs
- `flyctl` installed and logged in.
- Docker available locally (Fly can build remotely too, but local builds are easier to debug).

## 1) Generate certs locally (do NOT commit)
From repo root:
- `powershell -ExecutionPolicy Bypass -File scripts/gen-dot-certs.ps1`

This generates TLS materials locally under `certs/` for your development machine.

## 2) Create the Fly app
From repo root:
- `fly launch --no-deploy`

When prompted:
- Choose a region near you.
- You can skip DB setup.

## 3) Set TLS key/cert as Fly secrets

The entrypoint expects these Fly secrets (raw PEM):
- `TLS_SERVER_KEY` (PEM private key)
- `TLS_SERVER_CERT` (PEM certificate)

PowerShell helpers:

```powershell
$certPem = Get-Content .\certs\server.pem -Raw
$keyPem  = Get-Content .\certs\server.key -Raw

fly secrets set TLS_SERVER_CERT="$certPem" TLS_SERVER_KEY="$keyPem"
```

At startup, the container writes them to:
- `/data/server.key`
- `/data/server.pem`

## 4) Deploy
- `fly deploy`

## 5) Create a WireGuard peer and connect
- `fly wireguard create`

After connecting, you can reach the app over Fly private networking.

## 6) Test DoT over WireGuard
From your machine (after WireGuard is up), connect to the app’s 6PN address.

To find it:
- `fly ips private`

Then test TLS handshake (replace `<6pn-ip>`):
- `openssl s_client -connect [<6pn-ip>]:853 -servername dot.local -CAfile certs/ca.pem`

Note: the CA file is for your client validation; it is not deployed to Fly.

## Public exposure warning
Exposing a recursive resolver publicly is high-risk (abuse/amplification). If you decide to make it public:
- re-evaluate access controls (Fly proxying may obscure client IP)
- consider upstream forwarding mode or additional gating (VPN/mTLS) instead of open Internet access
