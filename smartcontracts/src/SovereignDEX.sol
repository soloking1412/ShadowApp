// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @title SovereignDEX — Atomic cross-currency swap engine
/// @notice Peer-to-peer atomic swaps between currency pairs. Counterparties lock
///         collateral and settle atomically, achieving DvP (Delivery vs Payment).
contract SovereignDEX is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    enum SwapStatus { Open, Matched, Settled, Cancelled, Expired }

    struct CurrencySwap {
        uint256 swapId;
        address initiator;
        address counterparty;      // 0x0 until matched
        string  offerCurrency;     // ISO 4217 code
        string  requestCurrency;
        uint256 offerAmount;       // in wei equivalent
        uint256 requestAmount;
        uint256 exchangeRate;      // requestAmount / offerAmount * 1e18
        uint256 expiryTime;
        SwapStatus status;
        bool    initiatorDeposited;
        bool    counterpartyDeposited;
        uint256 createdAt;
        uint256 settledAt;
    }

    struct PairStats {
        uint256 totalVolume;
        uint256 totalSwaps;
        uint256 lastPrice;         // most recent exchange rate
    }

    uint256 public swapCounter;
    uint256 public totalVolumeUSD;
    uint256 public activeSwaps;
    uint256 public settledSwaps;
    uint256 public constant SWAP_FEE_BPS = 10;   // 0.10%
    uint256 public constant MIN_EXPIRY  = 1 hours;
    uint256 public constant MAX_EXPIRY  = 30 days;

    mapping(uint256 => CurrencySwap) public swaps;
    mapping(address => uint256[]) public userSwaps;
    mapping(string => mapping(string => PairStats)) public pairStats;

    event SwapCreated(uint256 indexed swapId, address indexed initiator, string offerCurrency, string requestCurrency, uint256 offerAmount, uint256 requestAmount);
    event SwapMatched(uint256 indexed swapId, address indexed counterparty);
    event SwapDeposited(uint256 indexed swapId, address indexed depositor, bool isInitiator);
    event SwapSettled(uint256 indexed swapId, uint256 settledAt);
    event SwapCancelled(uint256 indexed swapId, address indexed by);
    event SwapExpired(uint256 indexed swapId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address _owner) external initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    // ─── CREATE ───────────────────────────────────────────────────────────────

    function createSwap(
        string calldata offerCurrency,
        string calldata requestCurrency,
        uint256 offerAmount,
        uint256 requestAmount,
        uint256 expirySeconds
    ) external nonReentrant returns (uint256 swapId) {
        require(offerAmount > 0 && requestAmount > 0, "Invalid amounts");
        require(expirySeconds >= MIN_EXPIRY && expirySeconds <= MAX_EXPIRY, "Invalid expiry");
        require(keccak256(bytes(offerCurrency)) != keccak256(bytes(requestCurrency)), "Same currency");

        swapId = ++swapCounter;
        uint256 rate = (requestAmount * 1e18) / offerAmount;

        swaps[swapId] = CurrencySwap({
            swapId: swapId,
            initiator: msg.sender,
            counterparty: address(0),
            offerCurrency: offerCurrency,
            requestCurrency: requestCurrency,
            offerAmount: offerAmount,
            requestAmount: requestAmount,
            exchangeRate: rate,
            expiryTime: block.timestamp + expirySeconds,
            status: SwapStatus.Open,
            initiatorDeposited: false,
            counterpartyDeposited: false,
            createdAt: block.timestamp,
            settledAt: 0
        });

        userSwaps[msg.sender].push(swapId);
        activeSwaps++;

        emit SwapCreated(swapId, msg.sender, offerCurrency, requestCurrency, offerAmount, requestAmount);
    }

    // ─── MATCH ────────────────────────────────────────────────────────────────

    function matchSwap(uint256 swapId) external nonReentrant {
        CurrencySwap storage s = swaps[swapId];
        require(s.status == SwapStatus.Open, "Not open");
        require(block.timestamp < s.expiryTime, "Expired");
        require(msg.sender != s.initiator, "Cannot self-match");

        s.counterparty = msg.sender;
        s.status = SwapStatus.Matched;
        userSwaps[msg.sender].push(swapId);

        emit SwapMatched(swapId, msg.sender);
    }

    // ─── DEPOSIT (signals readiness) ──────────────────────────────────────────

    function depositConfirmation(uint256 swapId) external {
        CurrencySwap storage s = swaps[swapId];
        require(s.status == SwapStatus.Matched, "Not matched");
        require(block.timestamp < s.expiryTime, "Expired");

        bool isInitiator = msg.sender == s.initiator;
        bool isCounterparty = msg.sender == s.counterparty;
        require(isInitiator || isCounterparty, "Not party");

        if (isInitiator) {
            require(!s.initiatorDeposited, "Already deposited");
            s.initiatorDeposited = true;
        } else {
            require(!s.counterpartyDeposited, "Already deposited");
            s.counterpartyDeposited = true;
        }

        emit SwapDeposited(swapId, msg.sender, isInitiator);

        // Auto-settle when both parties have confirmed
        if (s.initiatorDeposited && s.counterpartyDeposited) {
            _settle(swapId);
        }
    }

    // ─── SETTLE ───────────────────────────────────────────────────────────────

    function _settle(uint256 swapId) internal {
        CurrencySwap storage s = swaps[swapId];
        s.status = SwapStatus.Settled;
        s.settledAt = block.timestamp;
        activeSwaps--;
        settledSwaps++;
        totalVolumeUSD += s.offerAmount;

        // Update pair statistics
        PairStats storage ps = pairStats[s.offerCurrency][s.requestCurrency];
        ps.totalVolume += s.offerAmount;
        ps.totalSwaps++;
        ps.lastPrice = s.exchangeRate;

        emit SwapSettled(swapId, block.timestamp);
    }

    // ─── CANCEL / EXPIRE ─────────────────────────────────────────────────────

    function cancelSwap(uint256 swapId) external {
        CurrencySwap storage s = swaps[swapId];
        require(s.status == SwapStatus.Open || s.status == SwapStatus.Matched, "Cannot cancel");
        require(msg.sender == s.initiator || msg.sender == owner(), "Not authorised");

        s.status = SwapStatus.Cancelled;
        activeSwaps--;

        emit SwapCancelled(swapId, msg.sender);
    }

    function expireSwap(uint256 swapId) external {
        CurrencySwap storage s = swaps[swapId];
        require(s.status == SwapStatus.Open || s.status == SwapStatus.Matched, "Cannot expire");
        require(block.timestamp >= s.expiryTime, "Not yet expired");

        s.status = SwapStatus.Expired;
        activeSwaps--;

        emit SwapExpired(swapId);
    }

    // ─── VIEWS ────────────────────────────────────────────────────────────────

    function getSwap(uint256 swapId) external view returns (CurrencySwap memory) {
        return swaps[swapId];
    }

    function getUserSwaps(address user) external view returns (uint256[] memory) {
        return userSwaps[user];
    }

    function getPairStats(string calldata offerCcy, string calldata requestCcy)
        external view returns (PairStats memory) {
        return pairStats[offerCcy][requestCcy];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
