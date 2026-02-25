# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ShadowDapp** is a comprehensive DeFi sovereign financial platform built on Ethereum with 35+ smart contracts covering treasury, bonds, AMM, dark pool trading, governance, securities, and more. The project consists of:
- **Frontend:** Next.js 15 + React 19 + TypeScript with Wagmi/RainbowKit
- **Smart Contracts:** Solidity 0.8.24 with Foundry + OpenZeppelin upgradeable patterns
- **Local Dev:** Docker Compose orchestrating Anvil (local Ethereum node) + contract deployer + frontend

### Key Platform Components

**Financial Core:**
- **OICDTreasury** - Multi-currency stablecoin treasury (45+ currencies, 150% reserve ratio, KYC/compliance, active trading)
- **ObsidianCapital** - Institutional hedge fund with 8 trading strategies, 90-day lockup, dark pool integration
- **SGMToken** - 250B governance token with staking, yield, investment pools, 1-person-1-vote governance
- **SGMXToken** - 250Q security token with KYC/accreditation, dividend system, transfer restrictions

**Markets & Trading:**
- **DarkPool** - ZK-proof private order book with time-locked reveal mechanism
- **UniversalAMM** - Multi-pool constant product AMM with liquidity provision
- **SovereignDEX** - Decentralized exchange with advanced order types
- **HFTEngine** - High-frequency trading execution engine
- **PrimeBrokerage** - Institutional-grade brokerage services

**Governance & Institutions:**
- **SovereignInvestmentDAO** - Time-locked quadratic voting, proposal execution
- **OZFParliament** - Multi-ministry governance (Treasury, Finance, Infrastructure, Trade, Defense, Energy, Technology)
- **OrionScore** - Country credit scoring system

**Bonds & Securities:**
- **TwoDIBondTracker** - Sovereign bond issuance with ERC1155 (Infrastructure, Green, Social, Strategic, Emergency)
- **GovernmentSecuritiesSettlement** - T+2 settlement, collateralization
- **BondAuctionHouse** - Dutch auction system for bond issuance

**Trade & Infrastructure:**
- **FreeTradeRegistry** - Trade agreements, bills of lading, customs integration
- **DigitalTradeBlocks** - Tokenized trade finance instruments
- **InfrastructureAssets** - Infrastructure project tokenization
- **SpecialEconomicZone** - SEZ registry and incentive management

**Employment & Validation:**
- **JobsBoard** - On-chain job posting, completion, and payment system
- **PreAllocation** - Validator pre-allocation and staking rewards
- **AVSPlatform** - Actively Validated Services platform

**Credit & Lending:**
- **ICFLending** - Infrastructure Capital Financing with collateralized loans
- **FractionalReserveBanking** - Fractional reserve banking with regulatory ratios

**Supporting Systems:**
- **ForexReservesTracker** - Multi-currency reserves and 287 market corridors
- **PriceOracleAggregator** - Aggregated price feeds
- **ArmsTradeCompliance** - Arms trade regulatory compliance
- **DCMMarketCharter** - Digital Capital Market charter system
- **DigitalTradeExchange** - Digital trade execution platform

## Development Setup

### Prerequisites
- Docker & Docker Compose
- Node.js 20+ (for local frontend development outside Docker)

### Quick Start

```bash
# Start entire stack (Anvil + contract deployment + frontend)
docker compose up --force-recreate

# Frontend available at http://localhost:3000
# Anvil RPC at http://localhost:8545
```

### Individual Services

```bash
# Start only Anvil (local Ethereum node)
docker compose up anvil

# Deploy contracts to running Anvil
docker compose up deployer

# Start frontend only (requires Anvil + deployed contracts)
docker compose up frontend

# Optional: Start relayer for dark pool auto-reveal
docker compose --profile with-relayer up relayer
```

### Smart Contracts (Foundry)

```bash
cd smartcontracts

# Install dependencies
forge install

# Compile contracts
forge build

# Run tests
forge test

# Run specific test file
forge test --match-path test/OICDTreasury.t.sol

# Run specific test function
forge test --match-test testMintWithReserveRequirements

# Deploy to local Anvil (manual)
./deploy-local.sh

# Deploy with custom RPC
RPC_URL=http://localhost:8545 PRIVATE_KEY=0xac09... ./deploy-local.sh

# Generate ABIs (auto-generated in out/ directory after build)
forge build --silent
```

**Important:** Contracts use `via_ir = true` and `code_size_limit = 50000` for large contracts. Local Anvil configured to allow oversized contracts.

### Frontend (Next.js)

```bash
cd frontend

# Install dependencies
npm install

# Development server (uses contracts from docker-compose environment)
npm run dev

# Production build
npm run build

# Start production server
npm start

# Lint
npm run lint
```

## Architecture Guide

### Smart Contract Architecture

**Upgradeable Proxy Pattern:**
All major contracts use OpenZeppelin's UUPS proxy pattern:
- Implementation contracts in `smartcontracts/src/*.sol`
- Deployed via `ERC1967Proxy` wrapper
- Upgrade authorization via `_authorizeUpgrade()` with role-based access control

**Role-Based Access Control (RBAC):**
Contracts use OpenZeppelin AccessControl with role hierarchy:
- `ADMIN_ROLE` - System administration
- `MINTER_ROLE` / `BURNER_ROLE` - Token issuance control (OICDTreasury)
- `GOVERNMENT_ROLE` - Sovereign operations (compliance, freezing)
- `FUND_MANAGER_ROLE` / `TRADER_ROLE` - Investment management (ObsidianCapital)
- `BRIDGE_ROLE` - Cross-chain operations
- `ACTIVE_TRADER_ROLE` - Active trading module (OICDTreasury)

**Key Design Patterns:**
1. **Reserve Backing** - OICDTreasury enforces 150% reserve ratio with daily mint limits
2. **Lockup Periods** - ObsidianCapital uses 90-day lockup, governance uses time-locked voting
3. **Compliance Gating** - KYC verification with 90-day renewal requirement
4. **Oracle Integration** - Price validation with staleness checks (1-hour max age, 10% max deviation)
5. **Active Trading** - Scalp execution with daily volume limits and portfolio rebalancing

### Frontend Architecture

**State Management:**
- **Wagmi** - Ethereum interaction with React hooks
- **RainbowKit** - Wallet connection UI
- **Zustand** - Local state management (where used)
- **TanStack Query** - Async state management (via Wagmi)

**Contract Integration:**
- Contract addresses loaded from environment variables (`CONTRACTS` object in `lib/contracts.ts`)
- ABIs auto-generated from Foundry build, stored in `frontend/lib/abis/`
- Custom hooks per contract in `frontend/hooks/contracts/` (e.g., `useOICDTreasury.ts`, `useSGMToken.ts`)
- Each hook exports read hooks (`useXXX()`) and write hooks (`useXXXMutation()`)

**Component Structure:**
- `frontend/app/page.tsx` - Main dashboard with section navigation (35+ sections)
- `frontend/components/` - Feature components organized by domain:
  - `treasury/` - OICD Treasury UI
  - `capital/` - Obsidian Capital hedge fund
  - `sgm/` - SGM governance token
  - `sgmx/` - SGMX security token
  - `trading/` - Dark pool, CEX, terminal
  - `dao/` - Governance proposals
  - `bonds/` - Bond issuance/management
  - ... (see page.tsx imports for full list)

**Environment Variables:**
All contract addresses configured via `NEXT_PUBLIC_*_ADDRESS` environment variables (see `docker-compose.yml` lines 67-81 for defaults).

### Data Flow

**Write Operations:**
1. User action → Component state
2. Component calls write hook (e.g., `useMintOICD()`)
3. Hook calls `useWriteContract()` with contract ABI + function
4. Transaction submitted via connected wallet
5. `useWaitForTransactionReceipt()` tracks confirmation
6. UI updates on success/error via hook status flags

**Read Operations:**
1. Component calls read hook (e.g., `useOICDTreasury()`)
2. Hook uses `useReadContract()` with auto-refresh
3. Data returned as typed BigInt/struct
4. Component formats with `formatUnits()` for display

### Contract Deployment Flow

The `deploy-local.sh` script deploys 35 contracts sequentially:
1. Deploys implementation contract
2. Creates `ERC1967Proxy` with implementation address + initialization calldata
3. Returns proxy address (this is the contract address used by frontend)
4. Outputs all addresses as `NEXT_PUBLIC_*_ADDRESS` environment variables

**Deployment Order:**
- Phase 1 (Core): Treasury, Bonds, DarkPool, Banking, Forex, DAO, AMM (1-13)
- Phase 2 (Expansion): Securities, TradeBlocks, Parliament, Arms, Infrastructure, SEZ, Oracle (14-20)
- Phase 2C (Markets): SovereignDEX, BondAuction, Broker, HFT (21-24)
- Phase 3 (Employment): AVS, OTD, Orion, FreeTrade, ICF, PreAlloc, Jobs (25-31)
- Phase 4 (Exchange): DTX, DCM (32-33)
- Phase 5 (SGMX Ecosystem): SGM, SGMX tokens (34-35)

## Key Files & Locations

**Smart Contracts:**
- `smartcontracts/src/OICDTreasury.sol` - Multi-currency treasury (1246 lines)
- `smartcontracts/src/ObsidianCapital.sol` - Hedge fund (390 lines)
- `smartcontracts/src/SGMToken.sol` - Governance token (276 lines)
- `smartcontracts/src/SGMXToken.sol` - Security token (243 lines)
- `smartcontracts/foundry.toml` - Foundry configuration
- `smartcontracts/deploy-local.sh` - Local deployment script

**Frontend:**
- `frontend/app/page.tsx` - Main dashboard entry point
- `frontend/lib/contracts.ts` - Contract addresses and constants
- `frontend/lib/abis/` - Auto-generated ABIs
- `frontend/hooks/contracts/` - Contract interaction hooks
- `frontend/components/` - UI components organized by feature

**Infrastructure:**
- `docker-compose.yml` - Development environment orchestration
- `.env` (create from docker-compose defaults) - Environment variables

## Common Development Tasks

### Adding a New Contract

1. Create contract in `smartcontracts/src/NewContract.sol`
2. Add deployment to `deploy-local.sh`:
   ```bash
   echo "=== 36/36 NewContract ==="
   NEW_INIT=$(cast calldata "initialize(address)" "$DEPLOYER")
   NEW=$(deploy_proxy "src/NewContract.sol:NewContract" "$NEW_INIT")
   echo "  proxy: $NEW"
   echo "NEXT_PUBLIC_NEW_CONTRACT_ADDRESS=$NEW"
   ```
3. Add to `frontend/lib/contracts.ts`:
   ```typescript
   export const CONTRACTS = {
     // ...
     NewContract: process.env.NEXT_PUBLIC_NEW_CONTRACT_ADDRESS as `0x${string}`,
   }
   ```
4. Generate ABI: `cd smartcontracts && forge build`
5. Copy ABI: `cp out/NewContract.sol/NewContract.json frontend/lib/abis/`
6. Create hook: `frontend/hooks/contracts/useNewContract.ts`
7. Create component: `frontend/components/newfeature/NewContract.tsx`
8. Add to navigation in `frontend/app/page.tsx`

### Working with SGM/SGMX Tokens

**SGM Token (250 Billion Supply):**
- Governance token with 1-person-1-vote
- Staking for 2.5% yield
- 3 investment pools (Infrastructure, Growth, Liquidity)
- Paired to OICD at 0.001 OICD per SGM
- G-Score system (civic score 0-100)

**SGMX Token (250 Quadrillion Supply):**
- Security token with transfer restrictions
- Requires KYC/accreditation for transfers
- 3 share classes (0=common, 1=preferred, 2=institutional)
- Dividend distribution in OICD
- Cap table: 40% founders, 20% public, 40% reserved

### Working with OICD Treasury

**Multi-Currency Support:**
- 45 base currencies (USD, EUR, GBP, JPY, etc.) + expanding list
- Each currency has 250B daily mint limit
- 150% reserve ratio enforced
- Currency IDs defined in `lib/contracts.ts` CURRENCIES constant

**Active Trading Module:**
- `executeScalp()` - Execute arbitrage trades via Universal AMM
- `rebalancePortfolio()` - Adjust holdings based on target allocations
- Daily volume limits and max per-trade limits
- Oracle price validation with staleness checks

**Compliance:**
- KYC verification required for minting
- 90-day compliance check renewal
- Balance freezing for sanctioned addresses
- Transaction history tracking

### Troubleshooting

**"Contract not deployed" errors:**
- Ensure Anvil is running: `docker compose up anvil`
- Redeploy contracts: `docker compose up --force-recreate deployer`
- Check contract addresses in browser console (CONTRACTS object)

**"Connection refused" on frontend:**
- Verify Anvil is healthy: `cast block-number --rpc-url http://localhost:8545`
- Check docker network: `docker network inspect shadowdapp-network`
- Ensure deployer service completed successfully

**Contract size limit errors (EIP-170):**
- Local Anvil configured with `code_size_limit = 50000` (bypass EIP-170)
- For production deployment, consider splitting large contracts or optimizing
- Use `via_ir = true` in foundry.toml for better optimization

**Transaction reverts:**
- Check role assignments (most operations require specific roles)
- Verify reserve requirements for OICD minting
- Check lockup periods for ObsidianCapital withdrawals
- Ensure KYC verification for SGMX transfers
- Validate compliance check timestamps (must be < 90 days old)

## Documentation References

**Technical Specifications:**
- `docs-new/Obsidian Capital.pdf` - Hedge fund architecture and models
- `docs-new/OICD MODELS.pdf` - Financial mathematics formulas (bond pricing, arbitrage, Monte Carlo, synthetic spreads, peg function, reserve yield, infrastructure ROI)

**Implementation Notes:**
- OICD MODELS.pdf contains reference formulas for quantitative systems
- Most complex calculations (bond pricing, arbitrage metrics) are off-chain or oracle-based
- On-chain implementations focus on reserve enforcement, limits, and compliance
- Mathematical models serve as design specifications for trading algorithms

## Wallet & Accounts

**Default Anvil Test Accounts:**
- Deployer: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` (PK: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`)
- Test Account 1: `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
- Test Account 2: `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`
- Each account has 10,000 ETH balance

**RainbowKit Integration:**
- Frontend uses RainbowKit for wallet connection
- Supports MetaMask, WalletConnect, Rainbow, Coinbase Wallet
- Local development: Use injected wallet or RainbowKit test wallets

## Gas & Performance

**Foundry Optimizer:**
- `optimizer = true` with `optimizer_runs = 1` (optimize for deployment size)
- `via_ir = true` enables IR-based optimizer for complex contracts
- EVM version: `paris` (pre-Shanghai for broader compatibility)

**Contract Patterns:**
- UUPS upgradeable to avoid redeployment costs
- Batch operations for multi-currency/multi-token actions
- View functions for gas-free data reads
- Events for off-chain indexing instead of on-chain storage where possible
