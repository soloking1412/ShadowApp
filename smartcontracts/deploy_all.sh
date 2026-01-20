#!/bin/bash
set -e
source .env

echo "========================================="
echo "Deploying All 9 New Contracts"
echo "========================================="
echo ""

# Deploy and extract addresses
echo "1/9 Deploying GovernmentSecuritiesSettlement..."
GOV_SEC=$(forge create src/GovernmentSecuritiesSettlement.sol:GovernmentSecuritiesSettlement --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY --legacy --json | jq -r '.deployedTo')
echo "✅ $GOV_SEC"
sleep 2

echo "2/9 Deploying DigitalTradeBlocks..."
TRADE_BLOCKS=$(forge create src/DigitalTradeBlocks.sol:DigitalTradeBlocks --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY --legacy --json | jq -r '.deployedTo')
echo "✅ $TRADE_BLOCKS"
sleep 2

echo "3/9 Deploying OZFParliament..."
PARLIAMENT=$(forge create src/OZFParliament.sol:OZFParliament --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY --legacy --json | jq -r '.deployedTo')
echo "✅ $PARLIAMENT"
sleep 2

echo "4/9 Deploying ObsidianCapital..."
OBSIDIAN=$(forge create src/ObsidianCapital.sol:ObsidianCapital --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY --legacy --json | jq -r '.deployedTo')
echo "✅ $OBSIDIAN"
sleep 2

echo "5/9 Deploying ArmsTradeCompliance..."
ARMS=$(forge create src/ArmsTradeCompliance.sol:ArmsTradeCompliance --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY --legacy --json | jq -r '.deployedTo')
echo "✅ $ARMS"
sleep 2

echo "6/9 Deploying InfrastructureAssets..."
INFRA=$(forge create src/InfrastructureAssets.sol:InfrastructureAssets --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY --legacy --json | jq -r '.deployedTo')
echo "✅ $INFRA"
sleep 2

echo "7/9 Deploying PrimeBrokerage..."
PRIME=$(forge create src/PrimeBrokerage.sol:PrimeBrokerage --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY --legacy --json | jq -r '.deployedTo')
echo "✅ $PRIME"
sleep 2

echo "8/9 Deploying LiquidityAsAService..."
LAAS=$(forge create src/LiquidityAsAService.sol:LiquidityAsAService --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY --legacy --json | jq -r '.deployedTo')
echo "✅ $LAAS"
sleep 2

echo "9/9 Deploying SpecialEconomicZone..."
SEZ=$(forge create src/SpecialEconomicZone.sol:SpecialEconomicZone --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY --legacy --json | jq -r '.deployedTo')
echo "✅ $SEZ"

echo ""
echo "========================================="
echo "✅ ALL CONTRACTS DEPLOYED!"
echo "========================================="
echo ""

# Create .env.local file
cat > ../frontend/.env.local << EOF
# Previously deployed contracts
NEXT_PUBLIC_OICD_TREASURY_ADDRESS=0x0f27Ae0fC4DB7fdF98c2F8b59E6ad0e92bf8E99c
NEXT_PUBLIC_TWODI_BOND_TRACKER_ADDRESS=0xd8B47CD7E2C74F11e37FCed3CA0a5Ba0D22d69E3
NEXT_PUBLIC_DARK_POOL_ADDRESS=0xbDEe9aA6eBa2B87eb5A8D8b93E69AF2C99a7e3ae
NEXT_PUBLIC_FRACTIONAL_RESERVE_ADDRESS=0x2C0b35e45Ae1e7c37E40C34D2f3d92cC2Fc4cEAF
NEXT_PUBLIC_FOREX_RESERVES_ADDRESS=0x5f98Fe66cfA24F3b0D6925b0F6F3A67C1f0e4Ee6
NEXT_PUBLIC_SOVEREIGN_DAO_ADDRESS=0xF1Ac5A1e5AcB3e852fA9aDB5eADF5f88E6E6E7C4

# Newly deployed contracts
NEXT_PUBLIC_GOV_SECURITIES_ADDRESS=$GOV_SEC
NEXT_PUBLIC_DIGITAL_TRADE_BLOCKS_ADDRESS=$TRADE_BLOCKS
NEXT_PUBLIC_OZF_PARLIAMENT_ADDRESS=$PARLIAMENT
NEXT_PUBLIC_OBSIDIAN_CAPITAL_ADDRESS=$OBSIDIAN
NEXT_PUBLIC_ARMS_TRADE_ADDRESS=$ARMS
NEXT_PUBLIC_INFRASTRUCTURE_ASSETS_ADDRESS=$INFRA
NEXT_PUBLIC_PRIME_BROKERAGE_ADDRESS=$PRIME
NEXT_PUBLIC_LIQUIDITY_SERVICE_ADDRESS=$LAAS
NEXT_PUBLIC_SEZ_ADDRESS=$SEZ
EOF

echo "✅ Created frontend/.env.local with all addresses"
echo ""
echo "Copy these to your .env.local:"
cat ../frontend/.env.local
