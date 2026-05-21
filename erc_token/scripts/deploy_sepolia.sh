#!/usr/bin/env bash
# Declare, deploy, call, and invoke RestrictedToken on Sepolia.
# Uses account "sepolia" from ~/.starknet_accounts/starknet_open_zeppelin_accounts.json
# and [sncast.sepolia] in snfoundry.toml.
#
# Usage:
#   ./scripts/deploy_sepolia.sh              # declare + deploy + read calls + sample invoke
#   ./scripts/deploy_sepolia.sh declare      # declare only
#   ./scripts/deploy_sepolia.sh deploy       # deploy only (needs CLASS_HASH or prior declare)
#   ./scripts/deploy_sepolia.sh call         # read-only calls (needs CONTRACT_ADDRESS)
#   ./scripts/deploy_sepolia.sh invoke       # write calls (needs CONTRACT_ADDRESS)
#
# After deploy, contract address is saved to scripts/.deployed_address

set -euo pipefail

PROFILE="sepolia"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ADDRESS_FILE="${SCRIPT_DIR}/.deployed_address"
CLASS_HASH_FILE="${SCRIPT_DIR}/.class_hash"

# Your OpenZeppelin account on alpha-sepolia (from: sncast account list)
OWNER="0x5bab0ff83935ec8df4176e2aa2ffa5c1104600f8c7bd2752c41700499eb61c6"
# Second address for transfer demo (account "dave")
RECIPIENT="0x125fec364c413cde568d3c09c5e57074bc05804075f5cab0127ec69b578771e"

# Constructor: mint 1_000_000 tokens to OWNER (u256 = low, high)
INITIAL_SUPPLY_LOW="1000000"
INITIAL_SUPPLY_HIGH="0"

CONTRACT_NAME="RestrictedToken"

sncast_cmd() {
  sncast --profile "${PROFILE}" "$@"
}

parse_class_hash() {
  local output="$1"
  echo "${output}" | grep -oE 'class_hash: (0x[0-9a-fA-F]+)' | head -1 | awk '{print $2}'
}

parse_contract_address() {
  local output="$1"
  echo "${output}" | grep -oE 'contract_address: (0x[0-9a-fA-F]+)' | head -1 | awk '{print $2}'
}

load_contract_address() {
  if [[ -f "${ADDRESS_FILE}" ]]; then
    CONTRACT_ADDRESS="$(cat "${ADDRESS_FILE}")"
  else
    echo "Set CONTRACT_ADDRESS or run deploy first (missing ${ADDRESS_FILE})" >&2
    exit 1
  fi
}

do_build() {
  echo "==> Building (sncast uses release profile)..."
  cd "${PROJECT_DIR}"
  scarb build
}

do_declare() {
  echo "==> Declaring ${CONTRACT_NAME}..."
  cd "${PROJECT_DIR}"
  local output
  output="$(sncast_cmd declare --contract-name "${CONTRACT_NAME}" 2>&1 | tee /dev/stderr)"
  local class_hash
  class_hash="$(parse_class_hash "${output}")"
  if [[ -n "${class_hash}" ]]; then
    echo "${class_hash}" > "${CLASS_HASH_FILE}"
    echo "Saved class hash to ${CLASS_HASH_FILE}: ${class_hash}"
  fi
}

do_deploy() {
  echo "==> Deploying ${CONTRACT_NAME}..."
  cd "${PROJECT_DIR}"

  local -a deploy_args=(
    deploy
    --contract-name "${CONTRACT_NAME}"
    --constructor-calldata
    "${OWNER}"
    "${INITIAL_SUPPLY_LOW}"
    "${INITIAL_SUPPLY_HIGH}"
    "${OWNER}"
  )

  # If you declared separately and want a fixed class hash, uncomment:
  # local class_hash
  # class_hash="$(cat "${CLASS_HASH_FILE}")"
  # deploy_args=(deploy --class-hash "${class_hash}" --constructor-calldata ...)

  local output
  output="$(sncast_cmd "${deploy_args[@]}" 2>&1 | tee /dev/stderr)"
  local contract_address
  contract_address="$(parse_contract_address "${output}")"
  if [[ -n "${contract_address}" ]]; then
    echo "${contract_address}" > "${ADDRESS_FILE}"
    echo "Saved contract address to ${ADDRESS_FILE}: ${contract_address}"
    CONTRACT_ADDRESS="${contract_address}"
  else
    echo "Could not parse contract_address from deploy output." >&2
    exit 1
  fi
}

do_call() {
  load_contract_address
  echo "==> Read-only calls on ${CONTRACT_ADDRESS}..."

  echo "--- get_name"
  sncast_cmd call \
    --contract-address "${CONTRACT_ADDRESS}" \
    --function get_name

  echo "--- get_symbol"
  sncast_cmd call \
    --contract-address "${CONTRACT_ADDRESS}" \
    --function get_symbol

  echo "--- get_decimals"
  sncast_cmd call \
    --contract-address "${CONTRACT_ADDRESS}" \
    --function get_decimals

  echo "--- get_total_supply (returns u256: low, high)"
  sncast_cmd call \
    --contract-address "${CONTRACT_ADDRESS}" \
    --function get_total_supply

  echo "--- balance_of(OWNER)"
  sncast_cmd call \
    --contract-address "${CONTRACT_ADDRESS}" \
    --function balance_of \
    --calldata "${OWNER}"

  echo "--- get_transfer_limit"
  sncast_cmd call \
    --contract-address "${CONTRACT_ADDRESS}" \
    --function get_transfer_limit
}

do_invoke() {
  load_contract_address
  echo "==> Invokes on ${CONTRACT_ADDRESS} (account: ${PROFILE})..."

  # transfer 100 tokens to RECIPIENT (u256 amount = 100, 0)
  echo "--- transfer(RECIPIENT, 100)"
  sncast_cmd invoke \
    --contract-address "${CONTRACT_ADDRESS}" \
    --function transfer \
    --calldata "${RECIPIENT}" "100" "0"

  echo "--- approve(RECIPIENT, 50)"
  sncast_cmd invoke \
    --contract-address "${CONTRACT_ADDRESS}" \
    --function approve \
    --calldata "${RECIPIENT}" "50" "0"

  echo "--- balance_of(OWNER) after transfer"
  sncast_cmd call \
    --contract-address "${CONTRACT_ADDRESS}" \
    --function balance_of \
    --calldata "${OWNER}"

  echo "--- balance_of(RECIPIENT) after transfer"
  sncast_cmd call \
    --contract-address "${CONTRACT_ADDRESS}" \
    --function balance_of \
    --calldata "${RECIPIENT}"
}

main() {
  local step="${1:-all}"

  case "${step}" in
    declare)
      do_build
      do_declare
      ;;
    deploy)
      do_build
      do_deploy
      ;;
    call)
      do_call
      ;;
    invoke)
      do_invoke
      ;;
    all)
      do_build
      do_declare
      do_deploy
      do_call
      do_invoke
      ;;
    *)
      echo "Unknown step: ${step}" >&2
      echo "Use: declare | deploy | call | invoke | all" >&2
      exit 1
      ;;
  esac

  echo "Done."
}

main "$@"
