// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title OICDBridge - COMPLETE PRODUCTION VERSION
 * @notice Atomic swap bridge between ERC-1155 and ERC-20 tokens
 */
contract OICDBridge is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    address public treasury;
    
    struct WrapperInfo {
        address wrapper;
        uint256 currencyId;
        bool active;
        uint256 totalWrapped;
        uint256 totalUnwrapped;
    }
    
    struct BridgeTransaction {
        uint256 txId;
        address user;
        uint256 currencyId;
        address wrapper;
        uint256 amount;
        bool isWrap;
        uint256 timestamp;
        uint256 feeCharged;
    }
    
    mapping(uint256 => WrapperInfo) public wrappers;
    mapping(address => uint256) public wrapperToCurrencyId;
    
    BridgeTransaction[] public transactions;
    
    uint256 public wrapFee;
    uint256 public unwrapFee;
    address public feeCollector;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public totalFeesCollected;
    
    event WrapperRegistered(uint256 indexed currencyId, address indexed wrapper);
    event WrapperDeactivated(uint256 indexed currencyId);
    event Wrapped(
        address indexed user,
        uint256 indexed currencyId,
        uint256 amount,
        uint256 fee,
        uint256 txId
    );
    event Unwrapped(
        address indexed user,
        uint256 indexed currencyId,
        uint256 amount,
        uint256 fee,
        uint256 txId
    );
    event FeesUpdated(uint256 wrapFee, uint256 unwrapFee);
    event FeesCollected(address indexed collector, uint256 amount);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address admin,
        address _treasury,
        address _feeCollector,
        uint256 _wrapFee,
        uint256 _unwrapFee
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        treasury = _treasury;
        feeCollector = _feeCollector;
        wrapFee = _wrapFee;
        unwrapFee = _unwrapFee;
    }
    
    function registerWrapper(
        uint256 currencyId,
        address wrapper
    ) external onlyRole(ADMIN_ROLE) {
        require(wrapper != address(0), "Invalid wrapper");
        require(wrappers[currencyId].wrapper == address(0), "Already registered");
        
        wrappers[currencyId] = WrapperInfo({
            wrapper: wrapper,
            currencyId: currencyId,
            active: true,
            totalWrapped: 0,
            totalUnwrapped: 0
        });
        
        wrapperToCurrencyId[wrapper] = currencyId;
        
        emit WrapperRegistered(currencyId, wrapper);
    }
    
    function wrap(
        uint256 currencyId,
        uint256 amount
    ) external nonReentrant whenNotPaused returns (uint256 netAmount) {
        require(amount > 0, "Invalid amount");
        
        WrapperInfo storage info = wrappers[currencyId];
        require(info.active, "Wrapper not active");
        
        // Calculate fee
        uint256 fee = (amount * wrapFee) / BASIS_POINTS;
        netAmount = amount - fee;
        
        // Transfer ERC-1155 from user to bridge
        IERC1155(treasury).safeTransferFrom(
            msg.sender,
            address(this),
            currencyId,
            amount,
            ""
        );
        
        // Mint ERC-20 wrapper tokens (net of fee)
        require(
            IWrapper(info.wrapper).mint(msg.sender, netAmount),
            "Mint failed"
        );
        
        // Handle fee
        if (fee > 0) {
            // Keep ERC-1155 tokens as fee
            IERC1155(treasury).safeTransferFrom(
                address(this),
                feeCollector,
                currencyId,
                fee,
                ""
            );
            totalFeesCollected += fee;
        }
        
        // Record transaction
        uint256 txId = transactions.length;
        transactions.push(BridgeTransaction({
            txId: txId,
            user: msg.sender,
            currencyId: currencyId,
            wrapper: info.wrapper,
            amount: amount,
            isWrap: true,
            timestamp: block.timestamp,
            feeCharged: fee
        }));
        
        info.totalWrapped += amount;
        
        emit Wrapped(msg.sender, currencyId, amount, fee, txId);
        
        return netAmount;
    }
    
    function unwrap(
        uint256 currencyId,
        uint256 amount
    ) external nonReentrant whenNotPaused returns (uint256 netAmount) {
        require(amount > 0, "Invalid amount");
        
        WrapperInfo storage info = wrappers[currencyId];
        require(info.active, "Wrapper not active");
        
        // Calculate fee
        uint256 fee = (amount * unwrapFee) / BASIS_POINTS;
        netAmount = amount - fee;
        
        // Burn ERC-20 wrapper tokens from user
        IWrapper(info.wrapper).burnFrom(msg.sender, amount);
        
        // Transfer ERC-1155 to user (net of fee)
        IERC1155(treasury).safeTransferFrom(
            address(this),
            msg.sender,
            currencyId,
            netAmount,
            ""
        );
        
        // Handle fee
        if (fee > 0) {
            IERC1155(treasury).safeTransferFrom(
                address(this),
                feeCollector,
                currencyId,
                fee,
                ""
            );
            totalFeesCollected += fee;
        }
        
        // Record transaction
        uint256 txId = transactions.length;
        transactions.push(BridgeTransaction({
            txId: txId,
            user: msg.sender,
            currencyId: currencyId,
            wrapper: info.wrapper,
            amount: amount,
            isWrap: false,
            timestamp: block.timestamp,
            feeCharged: fee
        }));
        
        info.totalUnwrapped += amount;
        
        emit Unwrapped(msg.sender, currencyId, amount, fee, txId);
        
        return netAmount;
    }
    
    function batchWrap(
        uint256[] memory currencyIds,
        uint256[] memory amounts
    ) external nonReentrant whenNotPaused returns (uint256[] memory netAmounts) {
        require(currencyIds.length == amounts.length, "Length mismatch");
        
        netAmounts = new uint256[](currencyIds.length);
        
        for (uint256 i = 0; i < currencyIds.length; i++) {
            netAmounts[i] = this.wrap(currencyIds[i], amounts[i]);
        }
        
        return netAmounts;
    }
    
    function batchUnwrap(
        uint256[] memory currencyIds,
        uint256[] memory amounts
    ) external nonReentrant whenNotPaused returns (uint256[] memory netAmounts) {
        require(currencyIds.length == amounts.length, "Length mismatch");
        
        netAmounts = new uint256[](currencyIds.length);
        
        for (uint256 i = 0; i < currencyIds.length; i++) {
            netAmounts[i] = this.unwrap(currencyIds[i], amounts[i]);
        }
        
        return netAmounts;
    }
    
    function setFees(uint256 _wrapFee, uint256 _unwrapFee) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(_wrapFee <= 500 && _unwrapFee <= 500, "Fee too high"); // Max 5%
        wrapFee = _wrapFee;
        unwrapFee = _unwrapFee;
        emit FeesUpdated(_wrapFee, _unwrapFee);
    }
    
    function setFeeCollector(address _feeCollector) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(_feeCollector != address(0), "Invalid address");
        feeCollector = _feeCollector;
    }
    
    function deactivateWrapper(uint256 currencyId) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        wrappers[currencyId].active = false;
        emit WrapperDeactivated(currencyId);
    }
    
    function activateWrapper(uint256 currencyId) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(wrappers[currencyId].wrapper != address(0), "Not registered");
        wrappers[currencyId].active = true;
    }
    
    function collectFees(uint256 currencyId, uint256 amount) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        IERC1155(treasury).safeTransferFrom(
            address(this),
            feeCollector,
            currencyId,
            amount,
            ""
        );
        
        emit FeesCollected(feeCollector, amount);
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    function getWrapper(uint256 currencyId) 
        external 
        view 
        returns (WrapperInfo memory) 
    {
        return wrappers[currencyId];
    }
    
    function getTransaction(uint256 txId) 
        external 
        view 
        returns (BridgeTransaction memory) 
    {
        require(txId < transactions.length, "Invalid txId");
        return transactions[txId];
    }
    
    function getUserTransactions(address user) 
        external 
        view 
        returns (BridgeTransaction[] memory) 
    {
        uint256 count = 0;
        for (uint256 i = 0; i < transactions.length; i++) {
            if (transactions[i].user == user) {
                count++;
            }
        }
        
        BridgeTransaction[] memory userTxs = new BridgeTransaction[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < transactions.length; i++) {
            if (transactions[i].user == user) {
                userTxs[index] = transactions[i];
                index++;
            }
        }
        
        return userTxs;
    }
    
    function getTotalTransactions() external view returns (uint256) {
        return transactions.length;
    }
    
    function calculateWrapFee(uint256 amount) external view returns (uint256) {
        return (amount * wrapFee) / BASIS_POINTS;
    }
    
    function calculateUnwrapFee(uint256 amount) external view returns (uint256) {
        return (amount * unwrapFee) / BASIS_POINTS;
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
    
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

interface IERC1155 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;
    
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

interface IWrapper {
    function mint(address to, uint256 amount) external returns (bool);
    function burnFrom(address from, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}