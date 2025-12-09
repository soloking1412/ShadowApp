// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title OICDWrapper - COMPLETE PRODUCTION VERSION
 * @notice ERC-20 wrapper for OICD treasury tokens with full DEX compatibility
 */
contract OICDWrapper is ERC20, ERC20Burnable, ERC20Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    
    address public immutable treasury;
    uint256 public immutable currencyId;
    
    struct UnwrapRequest {
        address requester;
        uint256 amount;
        uint256 requestTime;
        bool processed;
    }
    
    mapping(address => UnwrapRequest[]) public unwrapRequests;
    uint256 public unwrapDelay;
    
    event Wrapped(address indexed user, uint256 amount);
    event Unwrapped(address indexed user, uint256 amount);
    event UnwrapRequested(address indexed user, uint256 indexed requestId, uint256 amount);
    event UnwrapRequestProcessed(address indexed user, uint256 indexed requestId);
    
    constructor(
        string memory name,
        string memory symbol,
        address _treasury,
        uint256 _currencyId,
        address admin
    ) ERC20(name, symbol) {
        require(_treasury != address(0), "Invalid treasury");
        
        treasury = _treasury;
        currencyId = _currencyId;
        unwrapDelay = 0; // Immediate unwrap by default
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }
    
    function wrap(uint256 amount) external whenNotPaused returns (bool) {
        require(amount > 0, "Invalid amount");
        
        // Transfer ERC-1155 tokens from user to this contract
        IERC1155(treasury).safeTransferFrom(
            msg.sender,
            address(this),
            currencyId,
            amount,
            ""
        );
        
        // Mint ERC-20 tokens
        _mint(msg.sender, amount);
        
        emit Wrapped(msg.sender, amount);
        
        return true;
    }
    
    function unwrap(uint256 amount) external whenNotPaused returns (bool) {
        require(amount > 0, "Invalid amount");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        if (unwrapDelay > 0) {
            // Create unwrap request
            unwrapRequests[msg.sender].push(UnwrapRequest({
                requester: msg.sender,
                amount: amount,
                requestTime: block.timestamp,
                processed: false
            }));
            
            uint256 requestId = unwrapRequests[msg.sender].length - 1;
            
            // Burn ERC-20 tokens immediately
            _burn(msg.sender, amount);
            
            emit UnwrapRequested(msg.sender, requestId, amount);
        } else {
            // Immediate unwrap
            _burn(msg.sender, amount);
            
            IERC1155(treasury).safeTransferFrom(
                address(this),
                msg.sender,
                currencyId,
                amount,
                ""
            );
            
            emit Unwrapped(msg.sender, amount);
        }
        
        return true;
    }
    
    function processUnwrapRequest(uint256 requestId) external {
        require(requestId < unwrapRequests[msg.sender].length, "Invalid request");
        
        UnwrapRequest storage request = unwrapRequests[msg.sender][requestId];
        require(!request.processed, "Already processed");
        require(
            block.timestamp >= request.requestTime + unwrapDelay,
            "Delay not elapsed"
        );
        
        request.processed = true;
        
        // Transfer ERC-1155 tokens back to user
        IERC1155(treasury).safeTransferFrom(
            address(this),
            msg.sender,
            currencyId,
            request.amount,
            ""
        );
        
        emit UnwrapRequestProcessed(msg.sender, requestId);
        emit Unwrapped(msg.sender, request.amount);
    }
    
    function mint(address to, uint256 amount) 
        external 
        onlyRole(MINTER_ROLE) 
        returns (bool) 
    {
        _mint(to, amount);
        return true;
    }
    
    function setUnwrapDelay(uint256 delay) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(delay <= 7 days, "Delay too long");
        unwrapDelay = delay;
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    function getUnwrapRequests(address user) 
        external 
        view 
        returns (UnwrapRequest[] memory) 
    {
        return unwrapRequests[user];
    }
    
    function getPendingUnwrapCount(address user) external view returns (uint256 count) {
        UnwrapRequest[] storage requests = unwrapRequests[user];
        for (uint256 i = 0; i < requests.length; i++) {
            if (!requests[i].processed) {
                count++;
            }
        }
        return count;
    }
    
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
    
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