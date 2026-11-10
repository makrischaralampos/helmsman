# Security Policy

## Supported versions

Only the latest commit on `main` is supported. Every image published from `main` is
scanned, signed and attested, and older images are not patched.

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's private vulnerability reporting:
**Security tab > Report a vulnerability**.

You can expect an acknowledgement within 7 days.

## Supply-chain guarantees

- Images are built by GitHub Actions only, from `main`.
- Each image is scanned with Trivy and is signed only if no fixable HIGH or CRITICAL
  vulnerability is found.
- Images are signed keylessly with Cosign (Sigstore), and the signing identity is the
  `ci.yml` workflow on `refs/heads/main`.
- A signed SPDX SBOM (Syft) and SLSA build provenance are attached to every image.
- The deploy job re-verifies signature, SBOM attestation and provenance before deploying.
- All GitHub Actions are pinned to commit SHAs and updated through Dependabot.
