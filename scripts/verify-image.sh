#!/usr/bin/env bash
# Verify a published Helmsman image the way a consumer would.
# Usage: ./scripts/verify-image.sh <tag-or-digest>
#   e.g. ./scripts/verify-image.sh sha-abc1234
#        ./scripts/verify-image.sh sha256:0123...
set -euo pipefail

REPO="${REPO:-makrischaralampos/helmsman}"
IMAGE="ghcr.io/${REPO}"
ARG="${1:?usage: verify-image.sh <tag-or-digest>}"
IDENTITY="https://github.com/${REPO}/.github/workflows/ci.yml@refs/heads/main"
ISSUER="https://token.actions.githubusercontent.com"

for tool in cosign gh jq docker; do
  command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 1; }
done

if [[ "$ARG" == sha256:* ]]; then
  DIGEST="$ARG"
else
  DIGEST="$(docker buildx imagetools inspect "${IMAGE}:${ARG}" --format '{{.Manifest.Digest}}')"
fi
REF="${IMAGE}@${DIGEST}"
echo "Image: ${REF}"

echo
echo "==> 1/3 Cosign signature (keyless, pinned workflow identity)"
cosign verify "$REF" \
  --certificate-identity "$IDENTITY" \
  --certificate-oidc-issuer "$ISSUER" >/dev/null
echo "OK: signed by ${IDENTITY}"

echo
echo "==> 2/3 SBOM attestation (SPDX from Syft)"
cosign verify-attestation "$REF" --type spdxjson \
  --certificate-identity "$IDENTITY" \
  --certificate-oidc-issuer "$ISSUER" >/dev/null
echo "OK: SBOM attestation verified"

echo
echo "==> 3/3 SLSA build provenance"
gh attestation verify "oci://${REF}" --repo "$REPO" >/dev/null
echo "OK: provenance verified"

echo
echo "ALL CHECKS PASSED"
