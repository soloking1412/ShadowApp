#!/bin/sh
# ShadowDapp Local Deployer - Full Version 1.0
# Uses forge create (bypasses forge script's interactive size check)
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

DEPLOYER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
RPC="$RPC_URL"
PK="$PRIVATE_KEY"
OZ_PROXY="lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy"

echo "============================================"
echo " ShadowDapp Local Deployer - Version 1.0"
echo "============================================"

echo "[1/3] Installing forge-std..."
forge install foundry-rs/forge-std --no-git 2>/dev/null || true

echo "[2/3] Waiting for Anvil at $RPC..."
i=0
while ! cast block-number --rpc-url "$RPC" > /dev/null 2>&1; do
  i=$((i+1))
  [ $i -ge 30 ] && echo "ERROR: Anvil not reachable" && exit 1
  echo "  attempt $i/30..."
  sleep 3
done
echo "  Anvil ready at block $(cast block-number --rpc-url "$RPC" 2>/dev/null)"

echo "[3/3] Compiling contracts..."
forge build --silent 2>&1
echo "  Compile done."

# deploy_impl <path:Contract> => prints address
deploy_impl() {
  forge create "$1" \
    --rpc-url "$RPC" \
    --private-key "$PK" \
    --broadcast \
    --json 2>/dev/null \
  | grep -oE '"deployedTo"[[:space:]]*:[[:space:]]*"(0x[0-9a-fA-F]+)"' \
  | grep -oE '0x[0-9a-fA-F]+'
}

# deploy_proxy <path:Contract> <init_calldata> => prints proxy address
deploy_proxy() {
  IMPL=$(deploy_impl "$1")
  echo "  impl:  $IMPL" >&2
  forge create "$OZ_PROXY" \
    --rpc-url "$RPC" \
    --private-key "$PK" \
    --broadcast \
    --json \
    --constructor-args "$IMPL" "$2" 2>/dev/null \
  | grep -oE '"deployedTo"\s*:\s*"(0x[0-9a-fA-F]+)"' \
  | grep -oE '0x[0-9a-fA-F]+'
}

echo ""
echo "=== 1/13 OICDTreasury ==="
TREASURY_INIT=$(cast calldata \
  "initialize(string,address,uint256)" \
  "https://shadowdapp.com/metadata/{id}" \
  "$DEPLOYER" "250000000000000000000000000000" 2>/dev/null)
TREASURY=$(deploy_proxy "src/OICDTreasury.sol:OICDTreasury" "$TREASURY_INIT")
echo "  proxy: $TREASURY"

echo ""
echo "=== 2/13 TwoDIBondTracker ==="
BONDS_INIT=$(cast calldata \
  "initialize(address,string)" \
  "$DEPLOYER" "https://shadowdapp.com/bonds/{id}" 2>/dev/null)
BONDS=$(deploy_proxy "src/TwoDIBondTracker.sol:TwoDIBondTracker" "$BONDS_INIT")
echo "  proxy: $BONDS"

echo ""
echo "=== 3/13 DarkPool ==="
DARKPOOL_INIT=$(cast calldata \
  "initialize(address,uint256,uint256,uint256,address)" \
  "$DEPLOYER" "100000000000000000000000" "10000000000000000000000000000" "30" "$DEPLOYER" 2>/dev/null)
DARKPOOL=$(deploy_proxy "src/DarkPool.sol:DarkPool" "$DARKPOOL_INIT")
echo "  proxy: $DARKPOOL"

echo ""
echo "=== 4/13 FractionalReserveBanking ==="
BANKING_INIT=$(cast calldata \
  "initialize(address,uint256)" \
  "$DEPLOYER" "2000" 2>/dev/null)
BANKING=$(deploy_proxy "src/FractionalReserveBanking.sol:FractionalReserveBanking" "$BANKING_INIT")
echo "  proxy: $BANKING"

echo ""
echo "=== 5/13 ForexReservesTracker ==="
FOREX_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
FOREX=$(deploy_proxy "src/ForexReservesTracker.sol:ForexReservesTracker" "$FOREX_INIT")
echo "  proxy: $FOREX"

echo ""
echo "=== 6/13 SovereignInvestmentDAO ==="
DAO_INIT=$(cast calldata \
  "initialize(address,uint256,uint256,uint256)" \
  "$DEPLOYER" "604800" "172800" "55" 2>/dev/null)
DAO=$(deploy_proxy "src/SovereignInvestmentDAO.sol:SovereignInvestmentDAO" "$DAO_INIT")
echo "  proxy: $DAO"

echo ""
echo "=== 7/13 UniversalAMM ==="
AMM_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
AMM=$(deploy_proxy "src/UniversalAMM.sol:UniversalAMM" "$AMM_INIT")
echo "  proxy: $AMM"

echo ""
echo "=== 8/13 InviteManager ==="
INVITE_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
INVITE=$(deploy_proxy "src/InviteManager.sol:InviteManager" "$INVITE_INIT")
echo "  proxy: $INVITE"

echo ""
echo "=== 9/13 OGRBlacklist ==="
BLACKLIST_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
BLACKLIST=$(deploy_proxy "src/OGRBlacklist.sol:OGRBlacklist" "$BLACKLIST_INIT")
echo "  proxy: $BLACKLIST"

echo ""
echo "=== 10/13 LiquidityAsAService ==="
LAAS_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
LAAS=$(deploy_proxy "src/LiquidityAsAService.sol:LiquidityAsAService" "$LAAS_INIT")
echo "  proxy: $LAAS"

echo ""
echo "=== 11/13 ObsidianCapital ==="
# Uses DarkPool address; pass zero address for CEX (not deployed)
OBSIDIAN_INIT=$(cast calldata \
  "initialize(address,address,address)" \
  "$DEPLOYER" "${DARKPOOL:-0x0000000000000000000000000000000000000000}" "0x0000000000000000000000000000000000000000" 2>/dev/null)
OBSIDIAN=$(deploy_proxy "src/ObsidianCapital.sol:ObsidianCapital" "$OBSIDIAN_INIT")
echo "  proxy: $OBSIDIAN"

echo ""
echo "=== 12/13 PrimeBrokerage ==="
PRIME_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
PRIME=$(deploy_proxy "src/PrimeBrokerage.sol:PrimeBrokerage" "$PRIME_INIT")
echo "  proxy: $PRIME"

echo ""
echo "=== 13/13 ZKVerifier (no proxy) ==="
ZK=$(deploy_impl "src/ZKVerifier.sol:ZKVerifier")
echo "  addr:  $ZK"

# ── Phase 2 Contracts ────────────────────────────────────────────

echo ""
echo "=== 14/20 GovernmentSecuritiesSettlement ==="
GSS_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
GSS=$(deploy_proxy "src/GovernmentSecuritiesSettlement.sol:GovernmentSecuritiesSettlement" "$GSS_INIT")
echo "  proxy: $GSS"

echo ""
echo "=== 15/20 DigitalTradeBlocks ==="
DTB_INIT=$(cast calldata \
  "initialize(string,string,address)" \
  "OZF Trade Block" "OZFTB" "$DEPLOYER" 2>/dev/null)
DTB=$(deploy_proxy "src/DigitalTradeBlocks.sol:DigitalTradeBlocks" "$DTB_INIT")
echo "  proxy: $DTB"

echo ""
echo "=== 16/20 OZFParliament ==="
PARLIAMENT_INIT=$(cast calldata \
  "initialize(address,address,address)" \
  "$DEPLOYER" "$DEPLOYER" "$DEPLOYER" 2>/dev/null)
PARLIAMENT=$(deploy_proxy "src/OZFParliament.sol:OZFParliament" "$PARLIAMENT_INIT")
echo "  proxy: $PARLIAMENT"

echo ""
echo "=== 17/20 ArmsTradeCompliance ==="
ARMS_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
ARMS=$(deploy_proxy "src/ArmsTradeCompliance.sol:ArmsTradeCompliance" "$ARMS_INIT")
echo "  proxy: $ARMS"

echo ""
echo "=== 18/20 InfrastructureAssets ==="
INFRA_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
INFRA=$(deploy_proxy "src/InfrastructureAssets.sol:InfrastructureAssets" "$INFRA_INIT")
echo "  proxy: $INFRA"

echo ""
echo "=== 19/20 SpecialEconomicZone ==="
SEZ_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
SEZ=$(deploy_proxy "src/SpecialEconomicZone.sol:SpecialEconomicZone" "$SEZ_INIT")
echo "  proxy: $SEZ"

echo ""
echo "=== 20/24 PriceOracleAggregator ==="
ORACLE_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
ORACLE=$(deploy_proxy "src/PriceOracleAggregator.sol:PriceOracleAggregator" "$ORACLE_INIT")
echo "  proxy: $ORACLE"

# ── Phase 2C Contracts ────────────────────────────────────────────

echo ""
echo "=== 21/24 SovereignDEX ==="
SDEX_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
SDEX=$(deploy_proxy "src/SovereignDEX.sol:SovereignDEX" "$SDEX_INIT")
echo "  proxy: $SDEX"

echo ""
echo "=== 22/24 BondAuctionHouse ==="
BOND_AUCTION_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
BOND_AUCTION=$(deploy_proxy "src/BondAuctionHouse.sol:BondAuctionHouse" "$BOND_AUCTION_INIT")
echo "  proxy: $BOND_AUCTION"

echo ""
echo "=== 23/24 PublicBrokerRegistry ==="
BROKER_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
BROKER=$(deploy_proxy "src/PublicBrokerRegistry.sol:PublicBrokerRegistry" "$BROKER_INIT")
echo "  proxy: $BROKER"

echo ""
echo "=== 24/24 HFTEngine ==="
HFT_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
HFT=$(deploy_proxy "src/HFTEngine.sol:HFTEngine" "$HFT_INIT")
echo "  proxy: $HFT"

# ── Phase 3 Contracts ────────────────────────────────────────────

echo ""
echo "=== 25/31 AVSPlatform ==="
AVS_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
AVS=$(deploy_proxy "src/AVSPlatform.sol:AVSPlatform" "$AVS_INIT")
echo "  proxy: $AVS"

echo ""
echo "=== 26/31 OTDToken ==="
OTD_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
OTD=$(deploy_proxy "src/OTDToken.sol:OTDToken" "$OTD_INIT")
echo "  proxy: $OTD"

echo ""
echo "=== 27/31 OrionScore ==="
ORION_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
ORION=$(deploy_proxy "src/OrionScore.sol:OrionScore" "$ORION_INIT")
echo "  proxy: $ORION"

echo ""
echo "=== 28/31 FreeTradeRegistry ==="
FTR_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
FTR=$(deploy_proxy "src/FreeTradeRegistry.sol:FreeTradeRegistry" "$FTR_INIT")
echo "  proxy: $FTR"

echo ""
echo "=== 29/31 ICFLending ==="
ICF_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
ICF=$(deploy_proxy "src/ICFLending.sol:ICFLending" "$ICF_INIT")
echo "  proxy: $ICF"

echo ""
echo "=== 30/31 PreAllocation ==="
PREALLOC_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
PREALLOC=$(deploy_proxy "src/PreAllocation.sol:PreAllocation" "$PREALLOC_INIT")
echo "  proxy: $PREALLOC"

echo ""
echo "=== 31/33 JobsBoard ==="
JOBS_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
JOBS=$(deploy_proxy "src/JobsBoard.sol:JobsBoard" "$JOBS_INIT")
echo "  proxy: $JOBS"

echo ""
echo "=== 32/33 DigitalTradeExchange ==="
DTX_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
DTX=$(deploy_proxy "src/DigitalTradeExchange.sol:DigitalTradeExchange" "$DTX_INIT")
echo "  proxy: $DTX"

echo ""
echo "=== 33/33 DCMMarketCharter ==="
DCM_INIT=$(cast calldata "initialize(address)" "$DEPLOYER" 2>/dev/null)
DCM=$(deploy_proxy "src/DCMMarketCharter.sol:DCMMarketCharter" "$DCM_INIT")
echo "  proxy: $DCM"

echo ""
echo "============================================"
echo " Deployed Contract Addresses"
echo "============================================"
echo "# Version 1.0 (Core)"
echo "NEXT_PUBLIC_OICD_TREASURY_ADDRESS=$TREASURY"
echo "NEXT_PUBLIC_TWODI_BOND_TRACKER_ADDRESS=$BONDS"
echo "NEXT_PUBLIC_DARK_POOL_ADDRESS=$DARKPOOL"
echo "NEXT_PUBLIC_FRACTIONAL_RESERVE_ADDRESS=$BANKING"
echo "NEXT_PUBLIC_FOREX_RESERVES_ADDRESS=$FOREX"
echo "NEXT_PUBLIC_SOVEREIGN_DAO_ADDRESS=$DAO"
echo "NEXT_PUBLIC_UNIVERSAL_AMM_ADDRESS=$AMM"
echo "NEXT_PUBLIC_INVITE_MANAGER_ADDRESS=$INVITE"
echo "NEXT_PUBLIC_OGR_BLACKLIST_ADDRESS=$BLACKLIST"
echo "NEXT_PUBLIC_LIQUIDITY_SERVICE_ADDRESS=$LAAS"
echo "NEXT_PUBLIC_OBSIDIAN_CAPITAL_ADDRESS=$OBSIDIAN"
echo "NEXT_PUBLIC_PRIME_BROKERAGE_ADDRESS=$PRIME"
echo "NEXT_PUBLIC_ZK_VERIFIER_ADDRESS=$ZK"
echo "# Phase 2 Expansion"
echo "NEXT_PUBLIC_GOV_SECURITIES_ADDRESS=$GSS"
echo "NEXT_PUBLIC_DIGITAL_TRADE_BLOCKS_ADDRESS=$DTB"
echo "NEXT_PUBLIC_OZF_PARLIAMENT_ADDRESS=$PARLIAMENT"
echo "NEXT_PUBLIC_ARMS_TRADE_ADDRESS=$ARMS"
echo "NEXT_PUBLIC_INFRASTRUCTURE_ASSETS_ADDRESS=$INFRA"
echo "NEXT_PUBLIC_SEZ_ADDRESS=$SEZ"
echo "NEXT_PUBLIC_PRICE_ORACLE_ADDRESS=$ORACLE"
echo "# Phase 2C"
echo "NEXT_PUBLIC_SOVEREIGN_DEX_ADDRESS=$SDEX"
echo "NEXT_PUBLIC_BOND_AUCTION_ADDRESS=$BOND_AUCTION"
echo "NEXT_PUBLIC_BROKER_REGISTRY_ADDRESS=$BROKER"
echo "NEXT_PUBLIC_HFT_ENGINE_ADDRESS=$HFT"
echo "# Phase 3"
echo "NEXT_PUBLIC_AVS_PLATFORM_ADDRESS=$AVS"
echo "NEXT_PUBLIC_OTD_TOKEN_ADDRESS=$OTD"
echo "NEXT_PUBLIC_ORION_SCORE_ADDRESS=$ORION"
echo "NEXT_PUBLIC_FREE_TRADE_REGISTRY_ADDRESS=$FTR"
echo "NEXT_PUBLIC_ICF_LENDING_ADDRESS=$ICF"
echo "NEXT_PUBLIC_PRE_ALLOCATION_ADDRESS=$PREALLOC"
echo "NEXT_PUBLIC_JOBS_BOARD_ADDRESS=$JOBS"
echo "# Phase 4"
echo "NEXT_PUBLIC_DTX_ADDRESS=$DTX"
echo "NEXT_PUBLIC_DCM_CHARTER_ADDRESS=$DCM"
echo "============================================"
echo " All 33 contracts deployed!"
echo "============================================"
