/**
 * ShadowDapp Relayer Service
 *
 * This optional service monitors the DarkPool contract for commitments
 * that are ready to be revealed and can auto-reveal them if configured.
 *
 * Environment Variables:
 *   RPC_URL - Ethereum RPC endpoint
 *   PRIVATE_KEY - Relayer wallet private key
 *   DARK_POOL_ADDRESS - DarkPool contract address
 */

const { ethers } = require('ethers');

// Configuration
const RPC_URL = process.env.RPC_URL || 'http://localhost:8545';
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const DARK_POOL_ADDRESS = process.env.DARK_POOL_ADDRESS;

// DarkPool ABI (minimal for event watching)
const DARK_POOL_ABI = [
  'event OrderCommitted(bytes32 indexed commitment, address indexed trader, uint256 escrowAmount)',
  'event OrderRevealed(bytes32 indexed commitment, bytes32 indexed orderHash, address indexed trader)',
  'event CommitmentCancelled(bytes32 indexed commitment, address indexed trader, uint256 refundAmount)',
  'function commitmentTimestamps(bytes32) view returns (uint256)',
  'function commitments(bytes32) view returns (bool)',
  'function REVEAL_DELAY() view returns (uint256)',
];

// Track pending commitments
const pendingCommitments = new Map();

async function main() {
  console.log('Starting ShadowDapp Relayer...');
  console.log(`RPC URL: ${RPC_URL}`);
  console.log(`DarkPool: ${DARK_POOL_ADDRESS}`);

  // Connect to provider
  const provider = new ethers.JsonRpcProvider(RPC_URL);

  // Create wallet if private key provided
  let wallet = null;
  if (PRIVATE_KEY) {
    wallet = new ethers.Wallet(PRIVATE_KEY, provider);
    console.log(`Relayer address: ${wallet.address}`);
  }

  // Connect to DarkPool contract
  const darkPool = new ethers.Contract(DARK_POOL_ADDRESS, DARK_POOL_ABI, provider);

  // Get reveal delay
  const revealDelay = await darkPool.REVEAL_DELAY();
  console.log(`Reveal delay: ${revealDelay} seconds`);

  // Listen for new commitments
  darkPool.on('OrderCommitted', async (commitment, trader, escrowAmount) => {
    console.log(`\nNew commitment detected:`);
    console.log(`  Commitment: ${commitment}`);
    console.log(`  Trader: ${trader}`);
    console.log(`  Escrow: ${ethers.formatEther(escrowAmount)} ETH`);

    const timestamp = await darkPool.commitmentTimestamps(commitment);
    const revealTime = Number(timestamp) + Number(revealDelay);

    pendingCommitments.set(commitment, {
      trader,
      escrowAmount,
      timestamp: Number(timestamp),
      revealTime,
    });

    console.log(`  Can reveal at: ${new Date(revealTime * 1000).toISOString()}`);
  });

  // Listen for reveals
  darkPool.on('OrderRevealed', (commitment, orderHash, trader) => {
    console.log(`\nOrder revealed:`);
    console.log(`  Commitment: ${commitment}`);
    console.log(`  Order Hash: ${orderHash}`);
    console.log(`  Trader: ${trader}`);

    pendingCommitments.delete(commitment);
  });

  // Listen for cancellations
  darkPool.on('CommitmentCancelled', (commitment, trader, refundAmount) => {
    console.log(`\nCommitment cancelled:`);
    console.log(`  Commitment: ${commitment}`);
    console.log(`  Trader: ${trader}`);
    console.log(`  Refund: ${ethers.formatEther(refundAmount)} ETH`);

    pendingCommitments.delete(commitment);
  });

  // Periodic status check
  setInterval(() => {
    const now = Math.floor(Date.now() / 1000);
    console.log(`\n[${new Date().toISOString()}] Status:`);
    console.log(`  Pending commitments: ${pendingCommitments.size}`);

    for (const [commitment, data] of pendingCommitments) {
      const timeUntilReveal = data.revealTime - now;
      if (timeUntilReveal > 0) {
        console.log(`  ${commitment.slice(0, 10)}... - ${timeUntilReveal}s until reveal`);
      } else {
        console.log(`  ${commitment.slice(0, 10)}... - READY FOR REVEAL`);
      }
    }
  }, 60000); // Check every minute

  console.log('\nRelayer is running. Watching for events...');
}

main().catch((error) => {
  console.error('Relayer error:', error);
  process.exit(1);
});
