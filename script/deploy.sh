#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${RPC_URL:-}" || -z "${PRIVATE_KEY:-}" ]]; then
  echo "RPC_URL and PRIVATE_KEY must be set"
  exit 1
fi

if [[ -z "${ETHERSCAN_API_KEY:-}" ]]; then
  echo "ETHERSCAN_API_KEY must be set to verify on deployment"
  exit 1
fi

if [[ -z "${NAME:-}" || -z "${SYMBOL:-}" || -z "${WEIGHTS:-}" || -z "${ALLOWED_SEADROP:-}" ]]; then
  echo "NAME, SYMBOL, WEIGHTS, and ALLOWED_SEADROP must be set"
  exit 1
fi

echo "Deploying ERC721SeaDropCycled"
echo "RPC_URL=${RPC_URL}"
echo "NAME=${NAME}"
echo "SYMBOL=${SYMBOL}"
echo "WEIGHTS=${WEIGHTS}"
echo "ALLOWED_SEADROP=${ALLOWED_SEADROP}"
if [[ -n "${VERIFIER_URL:-}" ]]; then
  echo "VERIFIER_URL=${VERIFIER_URL}"
fi
echo "Verification: enabled"

VERIFY_ARGS="--verify --etherscan-api-key ${ETHERSCAN_API_KEY}"
if [[ -n "${VERIFIER_URL:-}" ]]; then
  VERIFY_ARGS="${VERIFY_ARGS} --verifier-url ${VERIFIER_URL}"
fi

forge script script/Deploy.s.sol:Deploy \
  --rpc-url "${RPC_URL}" \
  --private-key "${PRIVATE_KEY}" \
  --broadcast \
  ${VERIFY_ARGS}
