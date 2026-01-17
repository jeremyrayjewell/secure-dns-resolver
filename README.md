# Private DNS-over-TLS Resolver (Unbound)

Private, hardened DNS resolver for learning + portfolio purposes.

**Goals**
- Recursive resolver using Unbound
- DNSSEC validation
- DNS-over-TLS (DoT) on TCP/8853
- Private-only (NOT an open resolver)
- Clear, auditable configuration and documentation

**Quick start (local, Windows)**
1. Install Unbound + OpenSSL (see [docs/setup.md](docs/setup.md)).
2. Generate lab TLS certs:
   - Run `powershell -ExecutionPolicy Bypass -File scripts/gen-dot-certs.ps1`
3. Bootstrap root hints + trust anchor:
   - Run `powershell -ExecutionPolicy Bypass -File scripts/bootstrap-unbound.ps1`
4. Start Unbound (recommended: container with runtime-injected secrets):
   - See [docs/local_dev.md](docs/local_dev.md)
5. Test:
   - Plain DNS: `dig @127.0.0.1 example.com A +dnssec`
   - DoT: see [docs/testing.md](docs/testing.md)

**Repository layout**
- [configs/unbound/unbound.conf](configs/unbound/unbound.conf): minimal, hardened config with annotated blocks
- [configs/tls/openssl-dot.cnf](configs/tls/openssl-dot.cnf): SAN template for DoT certificate
- [scripts/gen-dot-certs.ps1](scripts/gen-dot-certs.ps1): generates CA + server certs for lab use
- [scripts/bootstrap-unbound.ps1](scripts/bootstrap-unbound.ps1): fetches root hints + bootstraps DNSSEC trust anchor
- [docs/setup.md](docs/setup.md): installation + configuration steps
- [docs/testing.md](docs/testing.md): dig/openssl/packet-capture verification
- [docs/threat_model.md](docs/threat_model.md): abuse prevention + security assumptions

**Non-goals**
- Public “open resolver” operation
- Complex feature sets (DoH/DoQ, RPZ, custom auth zones) unless explicitly added later

## Why this resolver does not work behind many VPNs 

Many consumer VPNs (including NordVPN in typical configurations) enforce a strict DNS egress policy:

- They block or intercept raw DNS traffic (UDP/TCP DNS) to prevent DNS leaks.
- A **recursive** resolver must be able to talk to the public DNS infrastructure (root/TLD/authoritative) over UDP/TCP DNS.
- So when the VPN blocks raw DNS egress, a recursive resolver cannot complete iterative resolution — this is expected and is a *security feature* of the VPN.

If you want Unbound to work in a VPN environment, you generally need one of these models:

- Run Unbound off-VPN (localhost recursion on a network that allows DNS egress)
- Run Unbound as a remote service (e.g., on Fly.io) and connect to it over DoT
- Use DoT upstream forwarding (hybrid mode) so Unbound does not need raw DNS egress

## Deployment models (Fly.io)

There are two clean, defensible deployment stories depending on your environment and threat model:

**Model A — pure recursive (strongest academically)**

Client → DoT → Fly.io Unbound → root/TLD/authoritative → DNSSEC

**Model B — VPN-compatible hybrid (modern operational security)**

Client → DoT → Fly.io Unbound → DoT → Cloudflare/Quad9

Model A demonstrates full protocol understanding (iterative recursion + DNSSEC chain validation).
Model B demonstrates operational reality: strong privacy + policy compliance when raw DNS egress is blocked.

## Repo hygiene (before GitHub)

Do not commit generated TLS materials.

- Keep these local only: `certs/*.key`, `certs/*.pem`, `certs/*.csr`, `certs/*.srl`
- This repo includes a `.gitignore` that ignores those paths.

If you ever generated certs and accidentally pushed them, treat them as compromised: rotate by re-running `scripts/gen-dot-certs.ps1` and purge git history before continuing.

## Fly.io deployment

This repo includes a minimal container setup that loads TLS materials from runtime secrets and writes them to `/data/server.key` and `/data/server.pem`.

- See [docs/fly.md](docs/fly.md)
- Local injection: [docs/local_dev.md](docs/local_dev.md)

