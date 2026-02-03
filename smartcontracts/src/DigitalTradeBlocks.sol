// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title DigitalTradeBlocks
 * @notice High-value digital trade blocks for established market players
 * @dev NFT-based trade blocks covering debt securities, infrastructure bonds, and financing
 */
contract DigitalTradeBlocks is
    Initializable,
    ERC721Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant APPRAISER_ROLE = keccak256("APPRAISER_ROLE");

    enum TradeBlockType {
        DebtSecurities,
        InfrastructureBonds,
        InfrastructureFinancing,
        SovereignDebt,
        CorporateDebt,
        ProjectFinance,
        StructuredFinance
    }

    enum TradeBlockStatus {
        Active,
        Locked,
        Traded,
        Settled,
        Defaulted
    }

    struct TradeBlock {
        uint256 tokenId;
        TradeBlockType blockType;
        string name;
        string description;
        address issuer;
        uint256 faceValue;
        uint256 currentValue;
        uint256 issuanceDate;
        uint256 maturityDate;
        uint256 yieldRate;
        string underlyingAssets; // JSON/IPFS hash of underlying assets
        TradeBlockStatus status;
        mapping(address => uint256) investors; // investor => investment amount
        address[] investorList;
        uint256 totalInvestment;
        uint256 minimumInvestment;
        string jurisdiction;
        bool fractional; // Can be fractionalized
    }

    struct TradeBlockOffer {
        uint256 offerId;
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
        uint256 expiryDate;
    }

    // State variables
    mapping(uint256 => TradeBlock) private tradeBlocks;
    mapping(uint256 => TradeBlockOffer) public offers;
    mapping(address => uint256[]) public ownerBlocks;

    uint256 public blockCounter;
    uint256 public offerCounter;
    uint256 public totalTradeBlockValue;
    uint256 public constant BASIS_POINTS = 10000;

    // Events
    event TradeBlockCreated(
        uint256 indexed tokenId,
        TradeBlockType blockType,
        address indexed issuer,
        uint256 faceValue,
        string name
    );

    event TradeBlockInvestment(
        uint256 indexed tokenId,
        address indexed investor,
        uint256 amount,
        uint256 totalInvestment
    );

    event TradeBlockOffered(
        uint256 indexed offerId,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    event TradeBlockSold(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 price
    );

    event TradeBlockValueUpdated(
        uint256 indexed tokenId,
        uint256 oldValue,
        uint256 newValue
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name, string memory symbol, address admin)
        public
        initializer
    {
        __ERC721_init(name, symbol);
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(ISSUER_ROLE, admin);
        _grantRole(APPRAISER_ROLE, admin);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(ADMIN_ROLE)
    {}

    /**
     * @notice Create a new digital trade block
     */
    function createTradeBlock(
        TradeBlockType blockType,
        string memory name,
        string memory description,
        uint256 faceValue,
        uint256 maturityDate,
        uint256 yieldRate,
        string memory underlyingAssets,
        uint256 minimumInvestment,
        string memory jurisdiction,
        bool fractional
    ) external onlyRole(ISSUER_ROLE) whenNotPaused returns (uint256) {
        require(faceValue > 0, "Invalid face value");
        require(maturityDate > block.timestamp, "Invalid maturity date");
        require(yieldRate <= BASIS_POINTS, "Invalid yield rate");

        uint256 tokenId = ++blockCounter;

        _safeMint(msg.sender, tokenId);

        TradeBlock storage tb = tradeBlocks[tokenId];
        tb.tokenId = tokenId;
        tb.blockType = blockType;
        tb.name = name;
        tb.description = description;
        tb.issuer = msg.sender;
        tb.faceValue = faceValue;
        tb.currentValue = faceValue;
        tb.issuanceDate = block.timestamp;
        tb.maturityDate = maturityDate;
        tb.yieldRate = yieldRate;
        tb.underlyingAssets = underlyingAssets;
        tb.status = TradeBlockStatus.Active;
        tb.minimumInvestment = minimumInvestment;
        tb.jurisdiction = jurisdiction;
        tb.fractional = fractional;

        ownerBlocks[msg.sender].push(tokenId);
        totalTradeBlockValue += faceValue;

        emit TradeBlockCreated(tokenId, blockType, msg.sender, faceValue, name);

        return tokenId;
    }

    /**
     * @notice Invest in a trade block (for fractional blocks)
     */
    function investInTradeBlock(uint256 tokenId)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        TradeBlock storage tb = tradeBlocks[tokenId];
        require(tb.fractional, "Block not fractional");
        require(tb.status == TradeBlockStatus.Active, "Block not active");
        require(msg.value >= tb.minimumInvestment, "Below minimum investment");

        if (tb.investors[msg.sender] == 0) {
            tb.investorList.push(msg.sender);
        }

        tb.investors[msg.sender] += msg.value;
        tb.totalInvestment += msg.value;

        emit TradeBlockInvestment(tokenId, msg.sender, msg.value, tb.totalInvestment);
    }

    /**
     * @notice Offer trade block for sale
     */
    function offerTradeBlock(uint256 tokenId, uint256 price, uint256 expiryDays)
        external
        whenNotPaused
    {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(price > 0, "Invalid price");

        uint256 offerId = ++offerCounter;

        offers[offerId] = TradeBlockOffer({
            offerId: offerId,
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true,
            expiryDate: block.timestamp + (expiryDays * 1 days)
        });

        emit TradeBlockOffered(offerId, tokenId, msg.sender, price);
    }

    /**
     * @notice Buy a trade block
     */
    function buyTradeBlock(uint256 offerId)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        TradeBlockOffer storage offer = offers[offerId];
        require(offer.active, "Offer not active");
        require(block.timestamp <= offer.expiryDate, "Offer expired");
        require(msg.value >= offer.price, "Insufficient payment");

        uint256 tokenId = offer.tokenId;
        address seller = offer.seller;

        // Transfer NFT
        _transfer(seller, msg.sender, tokenId);

        // Update ownership tracking
        ownerBlocks[msg.sender].push(tokenId);

        // Transfer payment
        (bool successSeller, ) = payable(seller).call{value: offer.price}("");
        require(successSeller, "Payment transfer failed");

        // Refund excess
        if (msg.value > offer.price) {
            (bool successRefund, ) = payable(msg.sender).call{value: msg.value - offer.price}("");
            require(successRefund, "Refund transfer failed");
        }

        // Mark offer as inactive
        offer.active = false;

        emit TradeBlockSold(tokenId, seller, msg.sender, offer.price);
    }

    /**
     * @notice Update trade block value (by appraiser)
     */
    function updateTradeBlockValue(uint256 tokenId, uint256 newValue)
        external
        onlyRole(APPRAISER_ROLE)
    {
        TradeBlock storage tb = tradeBlocks[tokenId];
        uint256 oldValue = tb.currentValue;

        totalTradeBlockValue = totalTradeBlockValue - oldValue + newValue;
        tb.currentValue = newValue;

        emit TradeBlockValueUpdated(tokenId, oldValue, newValue);
    }

    /**
     * @notice Get trade block details
     */
    function getTradeBlock(uint256 tokenId)
        external
        view
        returns (
            TradeBlockType blockType,
            string memory name,
            address issuer,
            uint256 faceValue,
            uint256 currentValue,
            uint256 maturityDate,
            TradeBlockStatus status,
            uint256 totalInvestment
        )
    {
        TradeBlock storage tb = tradeBlocks[tokenId];
        return (
            tb.blockType,
            tb.name,
            tb.issuer,
            tb.faceValue,
            tb.currentValue,
            tb.maturityDate,
            tb.status,
            tb.totalInvestment
        );
    }

    /**
     * @notice Get investor share in a trade block
     */
    function getInvestorShare(uint256 tokenId, address investor)
        external
        view
        returns (uint256)
    {
        return tradeBlocks[tokenId].investors[investor];
    }

    /**
     * @notice Get all investors in a trade block
     */
    function getInvestors(uint256 tokenId)
        external
        view
        returns (address[] memory)
    {
        return tradeBlocks[tokenId].investorList;
    }

    /**
     * @notice Get blocks owned by an address
     */
    function getOwnerBlocks(address owner)
        external
        view
        returns (uint256[] memory)
    {
        return ownerBlocks[owner];
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
