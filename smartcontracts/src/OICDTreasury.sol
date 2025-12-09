// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title OICDTreasury - COMPLETE PRODUCTION VERSION
 * @notice Multi-currency treasury system with full reserve management
 */
contract OICDTreasury is 
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant GOVERNMENT_ROLE = keccak256("GOVERNMENT_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // Currency IDs
    uint256 public constant USD = 1;
    uint256 public constant EUR = 2;
    uint256 public constant GBP = 3;
    uint256 public constant JPY = 4;
    uint256 public constant CHF = 5;
    uint256 public constant CNY = 6;
    uint256 public constant AUD = 7;
    uint256 public constant CAD = 8;
    uint256 public constant OTD = 9;
    
    struct Currency {
        uint256 currencyId;
        string symbol;
        string name;
        uint256 totalSupply;
        uint256 reserveBalance;
        uint256 reserveRatio;        // Basis points (e.g., 15000 = 150%)
        uint256 dailyMintLimit;
        uint256 dailyMinted;
        uint256 lastMintReset;
        bool active;
        address oracle;
    }
    
    struct Reserve {
        address assetAddress;
        uint256 amount;
        uint256 valuation;
        uint256 lastUpdate;
        bool active;
    }
    
    struct Transaction {
        uint256 txId;
        address from;
        address to;
        uint256 currencyId;
        uint256 amount;
        uint256 timestamp;
        bytes32 txHash;
        string txType;
    }
    
    struct FrozenBalance {
        uint256 amount;
        uint256 frozenAt;
        uint256 unfreezeAt;
        string reason;
        bool active;
    }
    
    struct ComplianceCheck {
        address user;
        bool kycVerified;
        bool sanctioned;
        uint256 lastCheck;
        string jurisdiction;
    }
    
    // State variables
    mapping(uint256 => Currency) public currencies;
    mapping(uint256 => Reserve[]) public reserves;
    mapping(address => mapping(uint256 => FrozenBalance)) public frozenBalances;
    mapping(address => ComplianceCheck) public complianceStatus;
    mapping(bytes32 => bool) public processedTransactions;
    
    Transaction[] public transactionHistory;
    
    uint256 public transactionCounter;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PRECISION = 1e18;
    
    uint256 public totalReserveValue;
    uint256 public minReserveRatio;
    uint256 public emergencyReserveRatio;
    
    bool public emergencyMode;
    
    // Events
    event CurrencyMinted(
        uint256 indexed currencyId,
        address indexed to,
        uint256 amount,
        uint256 newTotalSupply
    );
    event CurrencyBurned(
        uint256 indexed currencyId,
        address indexed from,
        uint256 amount,
        uint256 newTotalSupply
    );
    event ReserveDeposited(
        uint256 indexed currencyId,
        address indexed asset,
        uint256 amount,
        uint256 valuation
    );
    event ReserveWithdrawn(
        uint256 indexed currencyId,
        address indexed asset,
        uint256 amount
    );
    event BalanceFrozen(
        address indexed account,
        uint256 indexed currencyId,
        uint256 amount,
        string reason
    );
    event BalanceUnfrozen(
        address indexed account,
        uint256 indexed currencyId,
        uint256 amount
    );
    event ComplianceUpdated(
        address indexed user,
        bool kycVerified,
        bool sanctioned
    );
    event TransactionRecorded(
        uint256 indexed txId,
        address indexed from,
        address indexed to,
        uint256 currencyId,
        uint256 amount
    );
    event EmergencyModeActivated(address activator);
    event EmergencyModeDeactivated(address deactivator);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        string memory uri_,
        address admin,
        uint256 _dailyMintLimit
    ) public initializer {
        __ERC1155_init(uri_);
        __AccessControl_init();
        __Pausable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(BURNER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        minReserveRatio = 12000;           // 120%
        emergencyReserveRatio = 10000;     // 100%
        
        // Initialize currencies
        _initializeCurrency(USD, "OICD-USD", "OICD US Dollar", _dailyMintLimit, 15000);
        _initializeCurrency(EUR, "OICD-EUR", "OICD Euro", _dailyMintLimit, 15000);
        _initializeCurrency(GBP, "OICD-GBP", "OICD British Pound", _dailyMintLimit, 15000);
        _initializeCurrency(JPY, "OICD-JPY", "OICD Japanese Yen", _dailyMintLimit, 15000);
        _initializeCurrency(CHF, "OICD-CHF", "OICD Swiss Franc", _dailyMintLimit, 15000);
        _initializeCurrency(CNY, "OICD-CNY", "OICD Chinese Yuan", _dailyMintLimit, 15000);
        _initializeCurrency(AUD, "OICD-AUD", "OICD Australian Dollar", _dailyMintLimit, 15000);
        _initializeCurrency(CAD, "OICD-CAD", "OICD Canadian Dollar", _dailyMintLimit, 15000);
        _initializeCurrency(OTD, "OTD", "On-Trade Digital Dollar", _dailyMintLimit, 15000);
    }
    
    function _initializeCurrency(
        uint256 currencyId,
        string memory symbol,
        string memory name,
        uint256 dailyLimit,
        uint256 reserveRatio
    ) internal {
        currencies[currencyId] = Currency({
            currencyId: currencyId,
            symbol: symbol,
            name: name,
            totalSupply: 0,
            reserveBalance: 0,
            reserveRatio: reserveRatio,
            dailyMintLimit: dailyLimit,
            dailyMinted: 0,
            lastMintReset: block.timestamp,
            active: true,
            oracle: address(0)
        });
    }
    
    // ============ MINTING (Complete Implementation) ============
    
    function mint(
        address to,
        uint256 currencyId,
        uint256 amount,
        bytes memory data
    ) external onlyRole(MINTER_ROLE) nonReentrant whenNotPaused {
        require(to != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(currencies[currencyId].active, "Currency inactive");
        
        // Check compliance
        _checkCompliance(to);
        
        // Check daily mint limit
        _checkDailyMintLimit(currencyId, amount);
        
        // Check reserve requirements
        _checkReserveRequirements(currencyId, amount);
        
        // Mint tokens
        _mint(to, currencyId, amount, data);
        
        // Update currency state
        Currency storage currency = currencies[currencyId];
        currency.totalSupply += amount;
        currency.dailyMinted += amount;
        
        // Record transaction
        _recordTransaction(address(0), to, currencyId, amount, "MINT");
        
        emit CurrencyMinted(currencyId, to, amount, currency.totalSupply);
    }
    
    function mintBatch(
        address to,
        uint256[] memory currencyIds,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyRole(MINTER_ROLE) nonReentrant whenNotPaused {
        require(to != address(0), "Invalid address");
        require(currencyIds.length == amounts.length, "Length mismatch");
        
        _checkCompliance(to);
        
        for (uint256 i = 0; i < currencyIds.length; i++) {
            uint256 currencyId = currencyIds[i];
            uint256 amount = amounts[i];
            
            require(currencies[currencyId].active, "Currency inactive");
            require(amount > 0, "Invalid amount");
            
            _checkDailyMintLimit(currencyId, amount);
            _checkReserveRequirements(currencyId, amount);
            
            Currency storage currency = currencies[currencyId];
            currency.totalSupply += amount;
            currency.dailyMinted += amount;
            
            _recordTransaction(address(0), to, currencyId, amount, "MINT_BATCH");
            
            emit CurrencyMinted(currencyId, to, amount, currency.totalSupply);
        }
        
        _mintBatch(to, currencyIds, amounts, data);
    }
    
    function _checkDailyMintLimit(uint256 currencyId, uint256 amount) internal {
        Currency storage currency = currencies[currencyId];
        
        // Reset daily counter if needed
        if (block.timestamp >= currency.lastMintReset + 1 days) {
            currency.dailyMinted = 0;
            currency.lastMintReset = block.timestamp;
        }
        
        require(
            currency.dailyMinted + amount <= currency.dailyMintLimit,
            "Exceeds daily mint limit"
        );
    }
    
    function _checkReserveRequirements(uint256 currencyId, uint256 amount) internal view {
        Currency storage currency = currencies[currencyId];
        
        uint256 requiredReserve = (amount * currency.reserveRatio) / BASIS_POINTS;
        require(
            currency.reserveBalance >= requiredReserve,
            "Insufficient reserves"
        );
        
        // Check minimum reserve ratio after mint
        uint256 newSupply = currency.totalSupply + amount;
        uint256 newRatio = (currency.reserveBalance * BASIS_POINTS) / newSupply;
        
        require(
            newRatio >= (emergencyMode ? emergencyReserveRatio : minReserveRatio),
            "Would breach minimum reserve ratio"
        );
    }
    
    function _checkCompliance(address user) internal view {
        ComplianceCheck storage compliance = complianceStatus[user];
        
        // Allow admins and system roles to bypass
        if (hasRole(ADMIN_ROLE, user) || 
            hasRole(MINTER_ROLE, user) || 
            hasRole(BRIDGE_ROLE, user)) {
            return;
        }
        
        require(compliance.kycVerified, "KYC not verified");
        require(!compliance.sanctioned, "Address sanctioned");
        require(
            block.timestamp - compliance.lastCheck < 90 days,
            "Compliance check expired"
        );
    }
    
    // ============ BURNING (Complete Implementation) ============
    
    function burn(
        address from,
        uint256 currencyId,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) nonReentrant {
        require(from != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(currencies[currencyId].active, "Currency inactive");
        
        // Check unfrozen balance
        uint256 availableBalance = _getUnfrozenBalance(from, currencyId);
        require(availableBalance >= amount, "Insufficient unfrozen balance");
        
        // Burn tokens
        _burn(from, currencyId, amount);
        
        // Update currency state
        Currency storage currency = currencies[currencyId];
        currency.totalSupply -= amount;
        
        // Record transaction
        _recordTransaction(from, address(0), currencyId, amount, "BURN");
        
        emit CurrencyBurned(currencyId, from, amount, currency.totalSupply);
    }
    
    function burnBatch(
        address from,
        uint256[] memory currencyIds,
        uint256[] memory amounts
    ) external onlyRole(BURNER_ROLE) nonReentrant {
        require(from != address(0), "Invalid address");
        require(currencyIds.length == amounts.length, "Length mismatch");
        
        for (uint256 i = 0; i < currencyIds.length; i++) {
            uint256 currencyId = currencyIds[i];
            uint256 amount = amounts[i];
            
            require(currencies[currencyId].active, "Currency inactive");
            require(amount > 0, "Invalid amount");
            
            uint256 availableBalance = _getUnfrozenBalance(from, currencyId);
            require(availableBalance >= amount, "Insufficient unfrozen balance");
            
            Currency storage currency = currencies[currencyId];
            currency.totalSupply -= amount;
            
            _recordTransaction(from, address(0), currencyId, amount, "BURN_BATCH");
            
            emit CurrencyBurned(currencyId, from, amount, currency.totalSupply);
        }
        
        _burnBatch(from, currencyIds, amounts);
    }
    
    function _getUnfrozenBalance(address account, uint256 currencyId) 
        internal 
        view 
        returns (uint256) 
    {
        uint256 totalBalance = balanceOf(account, currencyId);
        FrozenBalance storage frozen = frozenBalances[account][currencyId];
        
        if (!frozen.active || block.timestamp >= frozen.unfreezeAt) {
            return totalBalance;
        }
        
        return totalBalance > frozen.amount ? totalBalance - frozen.amount : 0;
    }
    
    // ============ RESERVE MANAGEMENT (Complete Implementation) ============
    
    function depositReserve(
        uint256 currencyId,
        address assetAddress,
        uint256 amount,
        uint256 valuation
    ) external onlyRole(ADMIN_ROLE) nonReentrant {
        require(currencies[currencyId].active, "Currency inactive");
        require(assetAddress != address(0), "Invalid asset");
        require(amount > 0 && valuation > 0, "Invalid amounts");
        
        // Transfer asset to contract
        IERC20(assetAddress).transferFrom(msg.sender, address(this), amount);
        
        // Add to reserves
        reserves[currencyId].push(Reserve({
            assetAddress: assetAddress,
            amount: amount,
            valuation: valuation,
            lastUpdate: block.timestamp,
            active: true
        }));
        
        // Update currency reserves
        Currency storage currency = currencies[currencyId];
        currency.reserveBalance += valuation;
        totalReserveValue += valuation;
        
        emit ReserveDeposited(currencyId, assetAddress, amount, valuation);
    }
    
    function withdrawReserve(
        uint256 currencyId,
        uint256 reserveIndex,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) nonReentrant {
        require(reserveIndex < reserves[currencyId].length, "Invalid index");
        
        Reserve storage reserve = reserves[currencyId][reserveIndex];
        require(reserve.active, "Reserve inactive");
        require(reserve.amount >= amount, "Insufficient reserve amount");
        
        // Check if withdrawal would breach minimum reserve ratio
        Currency storage currency = currencies[currencyId];
        uint256 withdrawalValue = (reserve.valuation * amount) / reserve.amount;
        
        require(
            currency.reserveBalance > withdrawalValue,
            "Would deplete reserves"
        );
        
        uint256 newReserveBalance = currency.reserveBalance - withdrawalValue;
        uint256 newRatio = currency.totalSupply > 0 ?
            (newReserveBalance * BASIS_POINTS) / currency.totalSupply : BASIS_POINTS;
        
        require(
            newRatio >= minReserveRatio,
            "Would breach minimum reserve ratio"
        );
        
        // Transfer asset back
        IERC20(reserve.assetAddress).transfer(msg.sender, amount);
        
        // Update reserve
        reserve.amount -= amount;
        reserve.valuation = (reserve.valuation * reserve.amount) / (reserve.amount + amount);
        reserve.lastUpdate = block.timestamp;
        
        if (reserve.amount == 0) {
            reserve.active = false;
        }
        
        // Update currency reserves
        currency.reserveBalance -= withdrawalValue;
        totalReserveValue -= withdrawalValue;
        
        emit ReserveWithdrawn(currencyId, reserve.assetAddress, amount);
    }
    
    function updateReserveValuation(
        uint256 currencyId,
        uint256 reserveIndex,
        uint256 newValuation
    ) external onlyRole(ADMIN_ROLE) {
        require(reserveIndex < reserves[currencyId].length, "Invalid index");
        
        Reserve storage reserve = reserves[currencyId][reserveIndex];
        require(reserve.active, "Reserve inactive");
        
        uint256 oldValuation = reserve.valuation;
        reserve.valuation = newValuation;
        reserve.lastUpdate = block.timestamp;
        
        // Update currency reserves
        Currency storage currency = currencies[currencyId];
        if (newValuation > oldValuation) {
            uint256 increase = newValuation - oldValuation;
            currency.reserveBalance += increase;
            totalReserveValue += increase;
        } else {
            uint256 decrease = oldValuation - newValuation;
            currency.reserveBalance -= decrease;
            totalReserveValue -= decrease;
        }
    }
    
    // ============ FROZEN BALANCES (Complete Implementation) ============
    
    function freezeBalance(
        address account,
        uint256 currencyId,
        uint256 amount,
        uint256 duration,
        string memory reason
    ) external onlyRole(GOVERNMENT_ROLE) {
        require(account != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(balanceOf(account, currencyId) >= amount, "Insufficient balance");
        
        FrozenBalance storage frozen = frozenBalances[account][currencyId];
        
        // If already frozen, add to existing
        if (frozen.active && block.timestamp < frozen.unfreezeAt) {
            frozen.amount += amount;
            // Extend freeze period if new duration is longer
            uint256 newUnfreezeAt = block.timestamp + duration;
            if (newUnfreezeAt > frozen.unfreezeAt) {
                frozen.unfreezeAt = newUnfreezeAt;
            }
        } else {
            frozen.amount = amount;
            frozen.frozenAt = block.timestamp;
            frozen.unfreezeAt = block.timestamp + duration;
            frozen.reason = reason;
            frozen.active = true;
        }
        
        emit BalanceFrozen(account, currencyId, amount, reason);
    }
    
    function unfreezeBalance(
        address account,
        uint256 currencyId
    ) external onlyRole(GOVERNMENT_ROLE) {
        FrozenBalance storage frozen = frozenBalances[account][currencyId];
        require(frozen.active, "No frozen balance");
        
        uint256 amount = frozen.amount;
        
        frozen.amount = 0;
        frozen.active = false;
        
        emit BalanceUnfrozen(account, currencyId, amount);
    }
    
    function autoUnfreeze(address account, uint256 currencyId) external {
        FrozenBalance storage frozen = frozenBalances[account][currencyId];
        require(frozen.active, "No frozen balance");
        require(block.timestamp >= frozen.unfreezeAt, "Freeze period not ended");
        
        uint256 amount = frozen.amount;
        
        frozen.amount = 0;
        frozen.active = false;
        
        emit BalanceUnfrozen(account, currencyId, amount);
    }
    
    // ============ COMPLIANCE (Complete Implementation) ============
    
    function updateCompliance(
        address user,
        bool kycVerified,
        bool sanctioned,
        string memory jurisdiction
    ) external onlyRole(GOVERNMENT_ROLE) {
        complianceStatus[user] = ComplianceCheck({
            user: user,
            kycVerified: kycVerified,
            sanctioned: sanctioned,
            lastCheck: block.timestamp,
            jurisdiction: jurisdiction
        });
        
        emit ComplianceUpdated(user, kycVerified, sanctioned);
    }
    
    function batchUpdateCompliance(
        address[] memory users,
        bool[] memory kycVerified,
        bool[] memory sanctioned,
        string[] memory jurisdictions
    ) external onlyRole(GOVERNMENT_ROLE) {
        require(
            users.length == kycVerified.length &&
            kycVerified.length == sanctioned.length &&
            sanctioned.length == jurisdictions.length,
            "Length mismatch"
        );
        
        for (uint256 i = 0; i < users.length; i++) {
            complianceStatus[users[i]] = ComplianceCheck({
                user: users[i],
                kycVerified: kycVerified[i],
                sanctioned: sanctioned[i],
                lastCheck: block.timestamp,
                jurisdiction: jurisdictions[i]
            });
            
            emit ComplianceUpdated(users[i], kycVerified[i], sanctioned[i]);
        }
    }
    
    // ============ TRANSACTION TRACKING (Complete Implementation) ============
    
    function _recordTransaction(
        address from,
        address to,
        uint256 currencyId,
        uint256 amount,
        string memory txType
    ) internal {
        bytes32 txHash = keccak256(
            abi.encodePacked(from, to, currencyId, amount, block.timestamp, transactionCounter)
        );
        
        require(!processedTransactions[txHash], "Duplicate transaction");
        processedTransactions[txHash] = true;
        
        transactionHistory.push(Transaction({
            txId: transactionCounter++,
            from: from,
            to: to,
            currencyId: currencyId,
            amount: amount,
            timestamp: block.timestamp,
            txHash: txHash,
            txType: txType
        }));
        
        emit TransactionRecorded(
            transactionCounter - 1,
            from,
            to,
            currencyId,
            amount
        );
    }
    
    // ============ EMERGENCY FUNCTIONS ============
    
    function activateEmergencyMode() external onlyRole(ADMIN_ROLE) {
        require(!emergencyMode, "Already in emergency mode");
        emergencyMode = true;
        _pause();
        emit EmergencyModeActivated(msg.sender);
    }
    
    function deactivateEmergencyMode() external onlyRole(ADMIN_ROLE) {
        require(emergencyMode, "Not in emergency mode");
        emergencyMode = false;
        _unpause();
        emit EmergencyModeDeactivated(msg.sender);
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    function setCurrencyActive(uint256 currencyId, bool active) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        currencies[currencyId].active = active;
    }
    
    function setCurrencyOracle(uint256 currencyId, address oracle) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        currencies[currencyId].oracle = oracle;
    }
    
    function setDailyMintLimit(uint256 currencyId, uint256 limit) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        currencies[currencyId].dailyMintLimit = limit;
    }
    
    function setReserveRatio(uint256 currencyId, uint256 ratio) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(ratio >= minReserveRatio, "Below minimum");
        currencies[currencyId].reserveRatio = ratio;
    }
    
    function setMinReserveRatio(uint256 ratio) external onlyRole(ADMIN_ROLE) {
        require(ratio >= emergencyReserveRatio, "Below emergency ratio");
        minReserveRatio = ratio;
    }
    
    function setURI(string memory newuri) external onlyRole(ADMIN_ROLE) {
        _setURI(newuri);
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    // ============ VIEW FUNCTIONS ============
    
    function getCurrency(uint256 currencyId) 
        external 
        view 
        returns (Currency memory) 
    {
        return currencies[currencyId];
    }
    
    function getReserves(uint256 currencyId) 
        external 
        view 
        returns (Reserve[] memory) 
    {
        return reserves[currencyId];
    }
    
    function getFrozenBalance(address account, uint256 currencyId) 
        external 
        view 
        returns (FrozenBalance memory) 
    {
        return frozenBalances[account][currencyId];
    }
    
    function getUnfrozenBalance(address account, uint256 currencyId) 
        external 
        view 
        returns (uint256) 
    {
        return _getUnfrozenBalance(account, currencyId);
    }
    
    function getComplianceStatus(address user) 
        external 
        view 
        returns (ComplianceCheck memory) 
    {
        return complianceStatus[user];
    }
    
    function getTransaction(uint256 txId) 
        external 
        view 
        returns (Transaction memory) 
    {
        require(txId < transactionHistory.length, "Invalid txId");
        return transactionHistory[txId];
    }
    
    function getTransactionHistory(uint256 startId, uint256 count) 
        external 
        view 
        returns (Transaction[] memory) 
    {
        require(startId < transactionHistory.length, "Invalid startId");
        
        uint256 endId = startId + count;
        if (endId > transactionHistory.length) {
            endId = transactionHistory.length;
        }
        
        Transaction[] memory result = new Transaction[](endId - startId);
        for (uint256 i = startId; i < endId; i++) {
            result[i - startId] = transactionHistory[i];
        }
        
        return result;
    }
    
    function getTotalTransactions() external view returns (uint256) {
        return transactionHistory.length;
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
    
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal override whenNotPaused {
        super._update(from, to, ids, amounts);

        // Check compliance for transfers
        if (from != address(0) && to != address(0)) {
            _checkCompliance(to);

            // Check frozen balances
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 availableBalance = _getUnfrozenBalance(from, ids[i]);
                require(availableBalance >= amounts[i], "Amount frozen");
            }

            // Record transfers
            for (uint256 i = 0; i < ids.length; i++) {
                _recordTransaction(from, to, ids[i], amounts[i], "TRANSFER");
            }
        }
    }
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}