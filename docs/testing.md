# Testing and Verification

## 1) Validate configuration syntax
- `unbound-checkconf configs/unbound/unbound.conf`

## 2) Start Unbound
- Recommended (container + runtime-injected secrets): see [docs/local_dev.md](local_dev.md)

If you run Unbound directly on the host, ensure the TLS key/cert exist at the paths configured in `configs/unbound/unbound.conf`.

Watch logs:
- `Get-Content -Wait var\unbound.log`

## 3) Test recursive resolution + DNSSEC (plaintext localhost)

Using dig:
- `dig @127.0.0.1 example.com A +dnssec`

What to look for:
- Successful answer
- `ad` flag set in the response header for DNSSEC-validated data (depends on dig output formatting)

Test a domain with known DNSSEC issues (should fail with SERVFAIL):
- `dig @127.0.0.1 dnssec-failed.org A +dnssec`

## 4) Verify DNS-over-TLS service with OpenSSL

### Check the TLS handshake and certificate
If your server cert is signed by your lab CA:
- `openssl s_client -connect 127.0.0.1:8853 -servername dot.local -CAfile certs/ca.pem`

What to look for:
- `Verify return code: 0 (ok)`
- Certificate SANs include the name/IP you used

## 5) Query over DoT with dig

### Important note about dig versions
DoT support in `dig` depends on your BIND tools version/build.
If your `dig` does not support DoT flags, use a DoT-capable tool (e.g., `kdig`) for the DoT query portion.

If your `dig` supports DoT, typical patterns are:
- `dig +tcp +tls @127.0.0.1 -p 8853 example.com A`

If CA pinning flags are available in your build, supply the CA file.

## 6) Packet capture verification ideas (Wireshark/tcpdump)

### Wireshark (Windows)
Capture on your active interface and apply display filters:
- DoT traffic: `tcp.port == 8853`
- Plain DNS (should be absent off-box): `udp.port == 8053 or tcp.port == 8053`

What to verify:
- DoT packets show as TLS records; DNS payload should not be visible.
- No outbound/inbound plaintext DNS from clients if they are configured to use DoT.

### tcpdump (Linux/WSL)
If you test from a Linux host:
- `sudo tcpdump -ni any tcp port 8853`

You should see TLS handshakes and encrypted application data.

## 7) Negative tests (abuse prevention)
- From a non-allowed IP, confirm you get REFUSED/timeouts.
- Temporarily bind DoT to a LAN IP and verify host firewall blocks all but your client.

