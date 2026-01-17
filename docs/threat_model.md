# Threat Model (Private DoT Resolver)

## Purpose
This resolver is for **personal / controlled-client** use. The primary security goals are:
- Prevent accidental exposure as a **public open resolver**.
- Provide **authentic** answers via DNSSEC validation.
- Provide **confidentiality on the wire** between client and resolver via DoT.
- Provide clear operational guidance and guardrails suitable for a portfolio.

## Trust boundaries
- **Trusted**: your resolver host, its OS, and your explicit client machines.
- **Untrusted**: the local network (unless fully controlled), the public Internet, upstream authoritative nameservers.

## Assets
- Resolver availability (avoid being used in reflection/amplification).
- Correctness of DNS answers.
- Privacy of client DNS queries on the local network.
- TLS private key material (written at runtime to `/data/server.key`) and CA key (generated locally during development).

## Threats and mitigations

### 1) Becoming an open resolver (abuse amplification)
**Threat**: Resolver listens publicly and accepts recursion from the Internet.

**Mitigations**
- Bind only to localhost by default:
  - `interface: 127.0.0.1` and `interface: 127.0.0.1@8853`
- Default-deny ACLs:
  - `access-control: 0.0.0.0/0 refuse`
  - Add only specific client allow rules.
- Host firewall:
  - Permit TCP/8853 only from explicit client IP(s).

### 2) DNS spoofing / cache poisoning
**Threat**: Off-path attacker injects forged replies or exploits weak validation.

**Mitigations**
- DNSSEC validation enabled (`validator` module + embedded public IANA root trust anchor).
- `harden-dnssec-stripped: yes` to treat unexpected absence of DNSSEC data as failure when anchored.
- Conservative Unbound hardening options (glue validation, short-bufsize hardening).

### 3) Downgrade / privacy leakage on local network
**Threat**: Attacker observes or modifies plaintext DNS.

**Mitigations**
- Prefer DoT for clients.
- Keep plaintext DNS on localhost only (no LAN binding for plaintext DNS).
- Validate certs on clients (trust `ca.pem` and verify hostname/SAN).

### 4) TLS key compromise
**Threat**: Theft of `server.key` enables active MITM against clients that trust the CA.

**Mitigations**
- Restrict filesystem permissions.
- Keep CA key offline if moving beyond local lab.
- Rotate server certs periodically.

### 5) DNS rebinding attacks
**Threat**: Public domain resolves to RFC1918/ULA targets, enabling browser pivoting.

**Mitigations**
- `private-address:` filtering enabled.
- If you intentionally host internal names, use `private-domain:` exceptions for those zones.

## Residual risks
- If the OS is compromised, resolver integrity/confidentiality is compromised.
- Self-signed/lab CA trust distribution is operationally sensitive (avoid trusting the CA broadly).

