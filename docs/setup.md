# Setup (Windows first, Linux later)

This project is intentionally conservative: it starts as a **local-only resolver** and only later expands to LAN / deployment use.

Baseline policy for safety: keep Unbound bound only to `127.0.0.1` and `::1` until you have validated behavior (DNSSEC + DoT + refusal from non-local sources).

## Architecture (brief)
- **Client** (your machine or your controlled device) sends DNS queries.
- **Unbound** is the recursive resolver:
  - Performs iterative resolution starting at the DNS root.
  - Validates **DNSSEC** (chain of trust to the root trust anchor).
  - Offers **DoT** (DNS inside TLS) for client-to-resolver privacy.
- **Network controls** (ACL + interface binding) ensure it is **not an open resolver**.

## 1) Install prerequisites

### Option A (recommended for repeatable setup): install via package managers

#### Install OpenSSL (needed for generating TLS certs)
- Using winget:
  - `winget install OpenSSL.OpenSSL`

#### Install dig (for testing)
- Windows does not ship `dig`. Install BIND tools (includes `dig`). Two common options:
  - Install ISC BIND tools (from ISC), or
  - Use WSL and run `dig` from Linux.

#### Install Unbound
- Preferred: install from NLnet Labs (official distribution).
  - Download from NLnet Labs “Unbound” releases for Windows.
  - Verify hashes/signature if provided.

Avoid the `unbound-<version>.tar.gz` / source archive for Windows setup:
- It contains source code (no `unbound-anchor.exe` / `unbound.exe`).
- Use the Windows installer (or `winget install --id NLnetLabs.Unbound -e`) instead.

> Note: Package managers like Chocolatey may work (`choco install unbound`) but official releases are preferred for a security portfolio to keep provenance clear.

### Option B: manual install (explicit and auditable)
1. Download the latest Unbound for Windows from NLnet Labs.
2. Extract to a dedicated directory (example):
   - `C:\Program Files\Unbound\`
3. Confirm binaries exist:
   - `unbound.exe`, `unbound-anchor.exe`, and `unbound-checkconf.exe`
4. Add that folder to your PATH *or* run commands from that directory.

## 2) Repo bootstrap: trust anchor + root hints

From the repo root:
- `powershell -ExecutionPolicy Bypass -File scripts/bootstrap-unbound.ps1`

If Unbound isn't on your PATH yet, pass the full path to `unbound-anchor.exe`:
- `powershell -ExecutionPolicy Bypass -File scripts/bootstrap-unbound.ps1 -UnboundAnchorExe "C:\Program Files\Unbound\unbound-anchor.exe"`

What this does:
- Downloads `var/root.hints` from Internic (`named.root`)
- Generates/bootstraps `var/root.key` using `unbound-anchor -a`

Why this matters:
- **root.hints**: list of root nameserver addresses (bootstrap for recursion)
- **root.key**: DNSSEC trust anchor state; Unbound uses it to validate DNSSEC

## 3) Generate TLS certs for DoT

From the repo root:
- `powershell -ExecutionPolicy Bypass -File scripts/gen-dot-certs.ps1`

Outputs:
- `certs/ca.pem` and `certs/ca.key` (lab CA)
- `certs/server.pem` and `certs/server.key` (server certificate material for development)

Edit SANs as needed:
- Update [configs/tls/openssl-dot.cnf](../configs/tls/openssl-dot.cnf)
- If you will expose DoT on your LAN IP, add that IP to the SAN list.

Client trust requirement:
- For clients to validate DoT, the client must trust `certs/ca.pem`.
  - For Windows clients: import `ca.pem` into “Trusted Root Certification Authorities”.

Important: TLS materials are not stored in the repo
- This repo intentionally does not commit any private keys/certs.
- For container/Fly usage, TLS materials are injected at runtime via environment variables and written to `/data/server.key` and `/data/server.pem` by the entrypoint.
- See [docs/local_dev.md](local_dev.md) for local injection.

## 4) Start Unbound (foreground)

Run:
- `unbound-checkconf configs/unbound/unbound.conf`
- `unbound -d -c configs/unbound/unbound.conf`

Notes:
- `-d` keeps it in the foreground (best for learning + logging).
- Logs write to `var/unbound.log`.

## 5) Make it private (LAN access without becoming open)

Two layers must align:
1. **Bind only the interface(s) you intend to serve**
2. **Allow only your client IPs via `access-control`**

In [configs/unbound/unbound.conf](../configs/unbound/unbound.conf):
- Add an interface for DoT, for example:
  - `interface: 192.0.2.10@853`
- Allow only your client:
  - `access-control: 192.0.2.50/32 allow`

Keep the defaults:
- `access-control: 0.0.0.0/0 refuse`
- `access-control: ::0/0 refuse`

Operational note:
- Also enforce host firewall rules (Windows Defender Firewall): allow TCP/853 only from your client IP.

## 6) Linux notes (later deployment)
- On Debian/Ubuntu:
  - `sudo apt-get update`
  - `sudo apt-get install -y unbound openssl dnsutils tcpdump`
- Unbound service file and paths differ; keep configs in the repo and deploy via automation, not hand edits.

