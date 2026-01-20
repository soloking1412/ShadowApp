#!/bin/bash

# Simple deployment script for all new contracts
# Usage: bash deploy_simple.sh

set -e

echo "Starting deployment of all new contracts..."
echo "Network: Arbitrum Sepolia"
echo ""

# Load environment variables
source .env

# Get deployer address
DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)
echo "Deployer address: $DEPLOYER"
echo ""

# Check balance
BALANCE=$(cast balance $DEPLOYER --rpc-url $ARBITRUM_SEPOLIA_RPC_URL)
echo "Deployer balance: $BALANCE wei"
echo ""

# Deploy contracts
echo "1/9 Deploying GovernmentSecuritiesSettlement..."
GOV_SEC=$(forge create src/GovernmentSecuritiesSettlement.sol:GovernmentSecuritiesSettlement \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  --json | jq -r '.deployedTo')
echo "   Deployed to: $GOV_SEC"
echo ""

echo "2/9 Deploying DigitalTradeBlocks..."
TRADE_BLOCKS=$(forge create src/DigitalTradeBlocks.sol:DigitalTradeBlocks \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  --json | jq -r '.deployedTo')
echo "   Deployed to: $TRADE_BLOCKS"
echo ""

echo "3/9 Deploying OZFParliament..."
PARLIAMENT=$(forge create src/OZFParliament.sol:OZFParliament \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  --json | jq -r '.deployedTo')
echo "   Deployed to: $PARLIAMENT"
echo ""

echo "4/9 Deploying ObsidianCapital..."
OBSIDIAN=$(forge create src/ObsidianCapital.sol:ObsidianCapital \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  --json | jq -r '.deployedTo')
echo "   Deployed to: $OBSIDIAN"
echo ""

echo "5/9 Deploying ArmsTradeCompliance..."
ARMS_TRADE=$(forge create src/ArmsTradeCompliance.sol:ArmsTradeCompliance \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  --json | jq -r '.deployedTo')
echo "   Deployed to: $ARMS_TRADE"
echo ""

echo "6/9 Deploying InfrastructureAssets..."
INFRA=$(forge create src/InfrastructureAssets.sol:InfrastructureAssets \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  --json | jq -r '.deployedTo')
echo "   Deployed to: $INFRA"
echo ""

echo "7/9 Deploying PrimeBrokerage..."
PRIME=$(forge create src/PrimeBrokerage.sol:PrimeBrokerage \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  --json | jq -r '.deployedTo')
echo "   Deployed to: $PRIME"
echo ""

echo "8/9 Deploying LiquidityAsAService..."
LAAS=$(forge create src/LiquidityAsAService.sol:LiquidityAsAService \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  --json | jq -r '.deployedTo')
echo "   Deployed to: $LAAS"
echo ""

echo "9/9 Deploying SpecialEconomicZone..."
SEZ=$(forge create src/SpecialEconomicZone.sol:SpecialEconomicZone \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  --json | jq -r '.deployedTo')
echo "   Deployed to: $SEZ"
echo ""

echo "========================================="
echo "DEPLOYMENT COMPLETE!"
echo "========================================="
echo ""
echo "Add these to your frontend/.env.local:"
echo ""
echo "NEXT_PUBLIC_GOV_SECURITIES_ADDRESS=$GOV_SEC"
echo "NEXT_PUBLIC_DIGITAL_TRADE_BLOCKS_ADDRESS=$TRADE_BLOCKS"
echo "NEXT_PUBLIC_OZF_PARLIAMENT_ADDRESS=$PARLIAMENT"
echo "NEXT_PUBLIC_OBSIDIAN_CAPITAL_ADDRESS=$OBSIDIAN"
echo "NEXT_PUBLIC_ARMS_TRADE_ADDRESS=$ARMS_TRADE"
echo "NEXT_PUBLIC_INFRASTRUCTURE_ASSETS_ADDRESS=$INFRA"
echo "NEXT_PUBLIC_PRIME_BROKERAGE_ADDRESS=$PRIME"
echo "NEXT_PUBLIC_LIQUIDITY_SERVICE_ADDRESS=$LAAS"
echo "NEXT_PUBLIC_SEZ_ADDRESS=$SEZ"
echo ""

# Save to file
cat > ../frontend/.env.local.new << EOF
# Existing contracts (keep your current values)
NEXT_PUBLIC_OICD_TREASURY_ADDRESS=0x0f27Ae0fC4DB7fdF98c2F8b59E6ad0e92bf8E99c
NEXT_PUBLIC_TWODI_BOND_TRACKER_ADDRESS=0xd8B47CD7E2C74F11e37FCed3CA0a5Ba0D22d69E3
NEXT_PUBLIC_DARK_POOL_ADDRESS=0xbDEe9aA6eBa2B87eb5A8D8b93E69AF2C99a7e3ae
NEXT_PUBLIC_FRACTIONAL_RESERVE_ADDRESS=0x2C0b35e45Ae1e7c37E40C34D2f3d92cC2Fc4cEAF
NEXT_PUBLIC_FOREX_RESERVES_ADDRESS=0x5f98Fe66cfA24F3b0D6925b0F6F3A67C1f0e4Ee6
NEXT_PUBLIC_SOVEREIGN_DAO_ADDRESS=0xF1Ac5A1e5AcB3e852fA9aDB5eADF5f88E6E6E7C4

# New contracts deployed
NEXT_PUBLIC_GOV_SECURITIES_ADDRESS=$GOV_SEC
NEXT_PUBLIC_DIGITAL_TRADE_BLOCKS_ADDRESS=$TRADE_BLOCKS
NEXT_PUBLIC_OZF_PARLIAMENT_ADDRESS=$PARLIAMENT
NEXT_PUBLIC_OBSIDIAN_CAPITAL_ADDRESS=$OBSIDIAN
NEXT_PUBLIC_ARMS_TRADE_ADDRESS=$ARMS_TRADE
NEXT_PUBLIC_INFRASTRUCTURE_ASSETS_ADDRESS=$INFRA
NEXT_PUBLIC_PRIME_BROKERAGE_ADDRESS=$PRIME
NEXT_PUBLIC_LIQUIDITY_SERVICE_ADDRESS=$LAAS
NEXT_PUBLIC_SEZ_ADDRESS=$SEZ
EOF

echo "Environment file saved to: ../frontend/.env.local.new"
echo "Review and rename to .env.local when ready"
