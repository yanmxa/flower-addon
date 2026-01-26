#!/usr/bin/env python3
"""Generate TLS certificates for Flower federated learning.

This script generates:
- CA certificate (ca.crt, ca.key)
- Server certificate (server.pem, server.key) signed by CA

The certificates support localhost, 127.0.0.1, and ::1 as SANs.
"""

import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

CERT_DIR = Path("certificates")


def generate_key() -> rsa.RSAPrivateKey:
    """Generate an RSA private key."""
    return rsa.generate_private_key(
        public_exponent=65537,
        key_size=4096,
        backend=default_backend(),
    )


def generate_ca_certificate(
    private_key: rsa.RSAPrivateKey,
) -> x509.Certificate:
    """Generate a self-signed CA certificate."""
    subject = issuer = x509.Name([
        x509.NameAttribute(NameOID.COUNTRY_NAME, "US"),
        x509.NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, "California"),
        x509.NameAttribute(NameOID.LOCALITY_NAME, "San Francisco"),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Flower FL Demo"),
        x509.NameAttribute(NameOID.COMMON_NAME, "Flower CA"),
    ])

    now = datetime.now(timezone.utc)
    cert = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(issuer)
        .public_key(private_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now)
        .not_valid_after(now + timedelta(days=365))
        .add_extension(
            x509.BasicConstraints(ca=True, path_length=None),
            critical=True,
        )
        .add_extension(
            x509.KeyUsage(
                digital_signature=True,
                content_commitment=False,
                key_encipherment=False,
                data_encipherment=False,
                key_agreement=False,
                key_cert_sign=True,
                crl_sign=True,
                encipher_only=False,
                decipher_only=False,
            ),
            critical=True,
        )
        .sign(private_key, hashes.SHA256(), default_backend())
    )
    return cert


def generate_server_certificate(
    ca_key: rsa.RSAPrivateKey,
    ca_cert: x509.Certificate,
    server_key: rsa.RSAPrivateKey,
) -> x509.Certificate:
    """Generate a server certificate signed by the CA."""
    subject = x509.Name([
        x509.NameAttribute(NameOID.COUNTRY_NAME, "US"),
        x509.NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, "California"),
        x509.NameAttribute(NameOID.LOCALITY_NAME, "San Francisco"),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Flower FL Demo"),
        x509.NameAttribute(NameOID.COMMON_NAME, "Flower Server"),
    ])

    # Subject Alternative Names for localhost connections
    san = x509.SubjectAlternativeName([
        x509.DNSName("localhost"),
        x509.DNSName("superlink"),
        x509.DNSName("superlink.flower.svc.cluster.local"),
        x509.IPAddress(__import__("ipaddress").IPv4Address("127.0.0.1")),
        x509.IPAddress(__import__("ipaddress").IPv6Address("::1")),
    ])

    now = datetime.now(timezone.utc)
    cert = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(ca_cert.subject)
        .public_key(server_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now)
        .not_valid_after(now + timedelta(days=365))
        .add_extension(san, critical=False)
        .add_extension(
            x509.BasicConstraints(ca=False, path_length=None),
            critical=True,
        )
        .add_extension(
            x509.KeyUsage(
                digital_signature=True,
                content_commitment=False,
                key_encipherment=True,
                data_encipherment=False,
                key_agreement=False,
                key_cert_sign=False,
                crl_sign=False,
                encipher_only=False,
                decipher_only=False,
            ),
            critical=True,
        )
        .add_extension(
            x509.ExtendedKeyUsage([
                x509.oid.ExtendedKeyUsageOID.SERVER_AUTH,
            ]),
            critical=False,
        )
        .sign(ca_key, hashes.SHA256(), default_backend())
    )
    return cert


def save_key(key: rsa.RSAPrivateKey, path: Path) -> None:
    """Save a private key to a file."""
    pem = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=serialization.NoEncryption(),
    )
    path.write_bytes(pem)
    os.chmod(path, 0o600)
    print(f"Saved private key: {path}")


def save_cert(cert: x509.Certificate, path: Path) -> None:
    """Save a certificate to a file."""
    pem = cert.public_bytes(serialization.Encoding.PEM)
    path.write_bytes(pem)
    print(f"Saved certificate: {path}")


def main() -> None:
    """Generate all certificates."""
    CERT_DIR.mkdir(exist_ok=True)

    # Generate CA
    print("Generating CA certificate...")
    ca_key = generate_key()
    ca_cert = generate_ca_certificate(ca_key)
    save_key(ca_key, CERT_DIR / "ca.key")
    save_cert(ca_cert, CERT_DIR / "ca.crt")

    # Generate server certificate
    print("\nGenerating server certificate...")
    server_key = generate_key()
    server_cert = generate_server_certificate(ca_key, ca_cert, server_key)
    save_key(server_key, CERT_DIR / "server.key")
    save_cert(server_cert, CERT_DIR / "server.pem")

    print("\nCertificates generated successfully!")
    print(f"Location: {CERT_DIR.absolute()}")
    print("\nFiles created:")
    for f in sorted(CERT_DIR.iterdir()):
        print(f"  - {f.name}")


if __name__ == "__main__":
    main()
