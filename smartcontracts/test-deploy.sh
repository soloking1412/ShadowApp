#!/bin/sh
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1
RPC=http://anvil:8545
PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
DEPLOYER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
OZ_PROXY="lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy"

echo "=== Anvil block ==="
cast block-number --rpc-url "$RPC" 2>&1

echo ""
echo "=== Deploy ForexReservesTracker impl ==="
FOREX_IMPL=$(forge create src/ForexReservesTracker.sol:ForexReservesTracker \
  --rpc-url "$RPC" \
  --private-key "$PK" \
  --broadcast \
  --json 2>/dev/null \
  | grep -oE '"deployedTo"\s*:\s*"(0x[0-9a-fA-F]+)"' \
  | grep -oE '0x[0-9a-fA-F]+')
echo "FOREX_IMPL=$FOREX_IMPL"

echo ""
echo "=== Build init calldata ==="
FOREX_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
echo "FOREX_INIT=$FOREX_INIT"

echo ""
echo "=== Deploy ERC1967Proxy (flags BEFORE --constructor-args) ==="
forge create "$OZ_PROXY" \
  --rpc-url "$RPC" \
  --private-key "$PK" \
  --broadcast \
  --json \
  --constructor-args "$FOREX_IMPL" "$FOREX_INIT" 2>&1

echo ""
echo "=== Done ==="
