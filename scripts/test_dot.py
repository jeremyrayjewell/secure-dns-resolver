import ssl
import socket

import dns.message
import dns.query


def main() -> None:
    host = "secure-dns-resolver.fly.dev"
    # dnspython's tls() expects a numeric IP address.
    ip = socket.getaddrinfo(host, None, family=socket.AF_INET, type=socket.SOCK_STREAM)[0][4][0]

    q = dns.message.make_query("google.com", "A")

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    r = dns.query.tls(
        q,
        ip,
        port=8853,
        ssl_context=ctx,
        timeout=5,
    )

    if not r.answer:
        print(f"No answer section; rcode={r.rcode()} flags={r.flags}")
        print(r.to_text())
        raise SystemExit(2)

    for rrset in r.answer:
        for item in rrset:
            if hasattr(item, "address"):
                print(item.address)


if __name__ == "__main__":
    main()
