#!/usr/bin/env bash
# Post-deploy smoke test. Used identically by `make smoke` and by CI.
set -euo pipefail

NAMESPACE="${NAMESPACE:-helmsman}"
RELEASE="${RELEASE:-helmsman}"
LOCAL_PORT="${LOCAL_PORT:-18080}"
EXPECTED_COMMIT="${EXPECTED_COMMIT:-}"
BASE="http://127.0.0.1:${LOCAL_PORT}"
PF_LOG="$(mktemp)"

fail() {
  echo "SMOKE TEST FAILED: $*" >&2
  exit 1
}

echo "==> waiting for rollout"
kubectl -n "$NAMESPACE" rollout status "deploy/${RELEASE}" --timeout=120s

echo "==> opening port-forward to svc/${RELEASE}"
kubectl -n "$NAMESPACE" port-forward "svc/${RELEASE}" "${LOCAL_PORT}:80" >"$PF_LOG" 2>&1 &
PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null || true; rm -f "$PF_LOG"' EXIT

for i in $(seq 1 30); do
  if curl -fsS "${BASE}/healthz" >/dev/null 2>&1; then
    break
  fi
  if [ "$i" -eq 30 ]; then
    cat "$PF_LOG" >&2
    fail "service never became reachable"
  fi
  sleep 1
done

echo "==> GET /healthz"
curl -fsS "${BASE}/healthz" | grep -q '"UP"' || fail "/healthz did not report UP"

echo "==> GET /version"
VERSION_JSON="$(curl -fsS "${BASE}/version")"
echo "    ${VERSION_JSON}"
if [ -n "$EXPECTED_COMMIT" ]; then
  echo "$VERSION_JSON" | grep -q "\"commit\":\"${EXPECTED_COMMIT}\"" \
    || fail "deployed commit does not match expected commit ${EXPECTED_COMMIT}"
  echo "    commit matches ${EXPECTED_COMMIT}"
fi

echo "==> GET /nope (expect 404)"
CODE="$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/nope")"
[ "$CODE" = "404" ] || fail "expected 404 for unknown path, got ${CODE}"

echo "==> all replicas ready"
DESIRED="$(kubectl -n "$NAMESPACE" get "deploy/${RELEASE}" -o jsonpath='{.spec.replicas}')"
READY="$(kubectl -n "$NAMESPACE" get "deploy/${RELEASE}" -o jsonpath='{.status.readyReplicas}')"
[ "${READY:-0}" = "$DESIRED" ] || fail "ready replicas ${READY:-0} != desired ${DESIRED}"

echo "SMOKE TEST PASSED"
