// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ObsidianCapital
 * @notice Hedge Fund with Dark Pool Integration for Effective Trading Strategies
 * @dev Macro trading, currency stabilization, emerging markets FDI
 */
contract ObsidianCapital is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FUND_MANAGER_ROLE = keccak256("FUND_MANAGER_ROLE");
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
    bytes32 public constant INVESTOR_ROLE = keccak256("INVESTOR_ROLE");

    enum StrategyType {
        MacroPlay,
        CurrencyArbitrage,
        EmergingMarkets,
        InfrastructureFinancing,
        DarkPoolTrading,
        Quant,
        LongShort,
        EventDriven
    }

    enum InvestmentStatus {
        Active,
        Locked,
        Withdrawn,
        Liquidated
    }

    struct Investment {
        address investor;
        uint256 amount;
        uint256 shares;
        uint256 investmentDate;
        uint256 lockupEnd;
        InvestmentStatus status;
        uint256 profitShare;
    }

    struct TradingStrategy {
        uint256 strategyId;
        StrategyType strategyType;
        string name;
        address manager;
        uint256 allocatedCapital;
        uint256 currentValue;
        int256 pnl; // Profit and Loss
        uint256 tradingVolume;
        bool active;
        string[] marketCorridors; // Up to 287 corridors
    }

    struct Position {
        uint256 positionId;
        uint256 strategyId;
        string asset;
        bool isLong;
        uint256 size;
        uint256 entryPrice;
        uint256 currentPrice;
        uint256 openedAt;
        bool isOpen;
        int256 pnl;
    }

    // State variables
    mapping(address => Investment) public investments;
    mapping(uint256 => TradingStrategy) public strategies;
    mapping(uint256 => Position) public positions;
    mapping(string => uint256) public marketCorridorAllocations; // corridor => capital

    address[] public investors;
    uint256 public strategyCounter;
    uint256 public positionCounter;

    uint256 public totalAUM; // Assets Under Management
    uint256 public totalShares;
    uint256 public navPerShare; // Net Asset Value per share
    uint256 public managementFee; // Basis points
    uint256 public performanceFee; // Basis points
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant LOCKUP_PERIOD = 90 days;

    address public darkPoolAddress;
    address public cexAddress;

    // Events
    event InvestmentMade(
        address indexed investor,
        uint256 amount,
        uint256 shares,
        uint256 lockupEnd
    );

    event StrategyCreated(
        uint256 indexed strategyId,
        StrategyType strategyType,
        string name,
        uint256 allocatedCapital
    );

    event PositionOpened(
        uint256 indexed positionId,
        uint256 indexed strategyId,
        string asset,
        bool isLong,
        uint256 size
    );

    event PositionClosed(
        uint256 indexed positionId,
        int256 pnl
    );

    event NAVUpdated(uint256 newNAV, uint256 totalAUM);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _darkPoolAddress,
        address _cexAddress
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(FUND_MANAGER_ROLE, admin);

        darkPoolAddress = _darkPoolAddress;
        cexAddress = _cexAddress;
        managementFee = 300;
        performanceFee = 3000;
        navPerShare = 1e18;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(ADMIN_ROLE)
    {}

    /**
     * @notice Invest in the hedge fund
     */
    function invest() external payable whenNotPaused nonReentrant {
        require(msg.value > 0, "Invalid investment amount");

        uint256 shares = (msg.value * 1e18) / navPerShare;
        uint256 lockupEnd = block.timestamp + LOCKUP_PERIOD;

        if (investments[msg.sender].amount == 0) {
            investors.push(msg.sender);
            _grantRole(INVESTOR_ROLE, msg.sender);
        }

        investments[msg.sender].investor = msg.sender;
        investments[msg.sender].amount += msg.value;
        investments[msg.sender].shares += shares;
        investments[msg.sender].investmentDate = block.timestamp;
        investments[msg.sender].lockupEnd = lockupEnd;
        investments[msg.sender].status = InvestmentStatus.Active;

        totalAUM += msg.value;
        totalShares += shares;

        emit InvestmentMade(msg.sender, msg.value, shares, lockupEnd);
    }

    /**
     * @notice Create a trading strategy
     */
    function createStrategy(
        StrategyType strategyType,
        string memory name,
        uint256 allocatedCapital,
        string[] memory marketCorridors
    ) external onlyRole(FUND_MANAGER_ROLE) returns (uint256) {
        require(allocatedCapital <= totalAUM, "Insufficient AUM");

        uint256 strategyId = ++strategyCounter;

        strategies[strategyId] = TradingStrategy({
            strategyId: strategyId,
            strategyType: strategyType,
            name: name,
            manager: msg.sender,
            allocatedCapital: allocatedCapital,
            currentValue: allocatedCapital,
            pnl: 0,
            tradingVolume: 0,
            active: true,
            marketCorridors: marketCorridors
        });

        // Allocate capital to market corridors
        uint256 capitalPerCorridor = allocatedCapital / marketCorridors.length;
        for (uint256 i = 0; i < marketCorridors.length; i++) {
            marketCorridorAllocations[marketCorridors[i]] += capitalPerCorridor;
        }

        emit StrategyCreated(strategyId, strategyType, name, allocatedCapital);

        return strategyId;
    }

    /**
     * @notice Open a trading position
     */
    function openPosition(
        uint256 strategyId,
        string memory asset,
        bool isLong,
        uint256 size,
        uint256 entryPrice
    ) external onlyRole(TRADER_ROLE) returns (uint256) {
        TradingStrategy storage strategy = strategies[strategyId];
        require(strategy.active, "Strategy not active");
        require(size <= strategy.allocatedCapital, "Size exceeds allocation");

        uint256 positionId = ++positionCounter;

        positions[positionId] = Position({
            positionId: positionId,
            strategyId: strategyId,
            asset: asset,
            isLong: isLong,
            size: size,
            entryPrice: entryPrice,
            currentPrice: entryPrice,
            openedAt: block.timestamp,
            isOpen: true,
            pnl: 0
        });

        strategy.tradingVolume += size;

        emit PositionOpened(positionId, strategyId, asset, isLong, size);

        return positionId;
    }

    /**
     * @notice Close a trading position
     */
    function closePosition(uint256 positionId, uint256 exitPrice)
        external
        onlyRole(TRADER_ROLE)
    {
        Position storage position = positions[positionId];
        require(position.isOpen, "Position not open");

        // Calculate P&L
        int256 pnl;
        if (position.isLong) {
            pnl = int256(position.size) * (int256(exitPrice) - int256(position.entryPrice)) / int256(position.entryPrice);
        } else {
            pnl = int256(position.size) * (int256(position.entryPrice) - int256(exitPrice)) / int256(position.entryPrice);
        }

        position.currentPrice = exitPrice;
        position.pnl = pnl;
        position.isOpen = false;

        // Update strategy P&L
        TradingStrategy storage strategy = strategies[position.strategyId];
        strategy.pnl += pnl;
        strategy.currentValue = uint256(int256(strategy.allocatedCapital) + strategy.pnl);

        emit PositionClosed(positionId, pnl);
    }

    /**
     * @notice Update NAV (Net Asset Value)
     */
    function updateNAV() external onlyRole(FUND_MANAGER_ROLE) {
        uint256 totalValue = totalAUM;

        // Add strategy P&L
        for (uint256 i = 1; i <= strategyCounter; i++) {
            if (strategies[i].active) {
                totalValue = uint256(int256(totalValue) + strategies[i].pnl);
            }
        }

        totalAUM = totalValue;
        if (totalShares > 0) {
            navPerShare = (totalAUM * 1e18) / totalShares;
        }

        emit NAVUpdated(navPerShare, totalAUM);
    }

    /**
     * @notice Withdraw investment (after lockup)
     */
    function withdraw() external nonReentrant {
        Investment storage investment = investments[msg.sender];
        require(investment.status == InvestmentStatus.Active, "Investment not active");
        require(block.timestamp >= investment.lockupEnd, "Lockup period not ended");

        uint256 withdrawalAmount = (investment.shares * navPerShare) / 1e18;

        // Apply management and performance fees
        uint256 managementFeeAmount = (withdrawalAmount * managementFee) / BASIS_POINTS;
        uint256 netAmount = withdrawalAmount - managementFeeAmount;

        investment.status = InvestmentStatus.Withdrawn;
        totalShares -= investment.shares;
        totalAUM -= withdrawalAmount;

        (bool success, ) = payable(msg.sender).call{value: netAmount}("");
        require(success, "Transfer failed");
    }

    /**
     * @notice Get strategy performance
     */
    function getStrategyPerformance(uint256 strategyId)
        external
        view
        returns (
            string memory name,
            uint256 allocatedCapital,
            uint256 currentValue,
            int256 pnl,
            uint256 tradingVolume
        )
    {
        TradingStrategy storage strategy = strategies[strategyId];
        return (
            strategy.name,
            strategy.allocatedCapital,
            strategy.currentValue,
            strategy.pnl,
            strategy.tradingVolume
        );
    }

    /**
     * @notice Get fund performance
     */
    function getFundPerformance()
        external
        view
        returns (
            uint256 aum,
            uint256 nav,
            uint256 investorCount,
            uint256 activeStrategies
        )
    {
        uint256 activeCount = 0;
        for (uint256 i = 1; i <= strategyCounter; i++) {
            if (strategies[i].active) activeCount++;
        }

        return (totalAUM, navPerShare, investors.length, activeCount);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    receive() external payable {}
}
