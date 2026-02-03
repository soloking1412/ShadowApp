// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TwoDIBondTracker is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    enum BondType {
        StandardBond,
        GreenBond,
        SocialBond,
        SustainabilityBond,
        HybridBond
    }

    enum BondStatus {
        Proposed,
        Active,
        Performing,
        Matured,
        Defaulted,
        Called
    }

    struct BondParams {
        BondType bondType;
        string projectName;
        string country;
        uint256 totalSupply;
        uint256 faceValue;
        uint256 couponRate;
        uint256 maturityDate;
        uint256 couponFrequency;
    }

    enum PaymentCurrency { ETH, OICD }

    struct TwoDIBond {
        uint256 bondId;
        BondType bondType;
        address issuer;
        string projectName;
        string country;
        uint256 totalSupply;
        uint256 faceValue;
        uint256 couponRate;
        uint256 issuanceDate;
        uint256 maturityDate;
        uint256 lastCouponDate;
        BondStatus status;
        PaymentCurrency paymentCurrency;
    }

    mapping(uint256 => TwoDIBond) public bonds;
    mapping(uint256 => mapping(address => uint256)) public bondHoldings;
    mapping(uint256 => address[]) private bondHolders;
    mapping(uint256 => mapping(address => uint256)) private holderIndex;

    uint256 public bondCounter;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_BOND_AMOUNT = 1000 * 1e18;

    event BondIssued(uint256 indexed bondId, address indexed issuer, BondType bondType, uint256 totalSupply);
    event CouponPaid(uint256 indexed bondId, uint256 amount);
    event BondMatured(uint256 indexed bondId);

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, string memory uri) public initializer {
        __ERC1155_init(uri);
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(ISSUER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    function issueBond(BondParams memory params)
        external
        onlyRole(ISSUER_ROLE)
        whenNotPaused
        returns (uint256)
    {
        require(params.totalSupply >= MIN_BOND_AMOUNT, "Supply too low");
        require(params.maturityDate > block.timestamp, "Invalid maturity");
        require(params.couponRate <= 2000, "Coupon rate too high");

        uint256 bondId = ++bondCounter;

        bonds[bondId] = TwoDIBond({
            bondId: bondId,
            bondType: params.bondType,
            issuer: msg.sender,
            projectName: params.projectName,
            country: params.country,
            totalSupply: params.totalSupply,
            faceValue: params.faceValue,
            couponRate: params.couponRate,
            issuanceDate: block.timestamp,
            maturityDate: params.maturityDate,
            lastCouponDate: block.timestamp,
            status: BondStatus.Active,
            paymentCurrency: PaymentCurrency.ETH
        });

        bondHoldings[bondId][msg.sender] = params.totalSupply;
        _mint(msg.sender, bondId, params.totalSupply, "");

        emit BondIssued(bondId, msg.sender, params.bondType, params.totalSupply);

        return bondId;
    }

    function payCoupon(uint256 bondId) external payable nonReentrant whenNotPaused {
        TwoDIBond storage bond = bonds[bondId];
        require(bond.bondId != 0, "Bond does not exist");
        require(bond.status == BondStatus.Active, "Bond not active");
        require(block.timestamp >= bond.lastCouponDate + 30 days, "Too early");

        uint256 couponAmount = (bond.totalSupply * bond.couponRate) / BASIS_POINTS;
        require(msg.value >= couponAmount, "Insufficient payment");

        // SECURITY FIX: Update state before external calls
        bond.lastCouponDate = block.timestamp;

        uint256 totalShares = bond.totalSupply;
        address[] memory holders = _getBondHolders(bondId);

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint256 shares = bondHoldings[bondId][holder];
            if (shares > 0) {
                uint256 payment = (couponAmount * shares) / totalShares;
                (bool success, ) = holder.call{value: payment}("");
                require(success, "Transfer failed");
            }
        }

        emit CouponPaid(bondId, couponAmount);
    }

    function redeemAtMaturity(uint256 bondId) external nonReentrant {
        TwoDIBond storage bond = bonds[bondId];
        require(bond.bondId != 0, "Bond does not exist");
        require(block.timestamp >= bond.maturityDate, "Not matured");
        require(bond.status == BondStatus.Active || bond.status == BondStatus.Matured, "Invalid status");

        uint256 holderShares = bondHoldings[bondId][msg.sender];
        require(holderShares > 0, "No holdings");

        uint256 redemptionAmount = (bond.faceValue * holderShares) / bond.totalSupply;

        bondHoldings[bondId][msg.sender] = 0;
        bond.status = BondStatus.Matured;
        _burn(msg.sender, bondId, holderShares);

        (bool success, ) = msg.sender.call{value: redemptionAmount}("");
        require(success, "Transfer failed");

        emit BondMatured(bondId);
    }

    function _getBondHolders(uint256 bondId) internal view returns (address[] memory) {
        return bondHolders[bondId];
    }

    function _addBondHolder(uint256 bondId, address holder) internal {
        if (holderIndex[bondId][holder] == 0 && balanceOf(holder, bondId) == 0) {
            bondHolders[bondId].push(holder);
            holderIndex[bondId][holder] = bondHolders[bondId].length;
        }
    }

    function _removeBondHolder(uint256 bondId, address holder) internal {
        uint256 index = holderIndex[bondId][holder];
        if (index > 0 && balanceOf(holder, bondId) == 0) {
            uint256 lastIndex = bondHolders[bondId].length - 1;
            address lastHolder = bondHolders[bondId][lastIndex];

            bondHolders[bondId][index - 1] = lastHolder;
            holderIndex[bondId][lastHolder] = index;

            bondHolders[bondId].pop();
            delete holderIndex[bondId][holder];
        }
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override
    {
        super._update(from, to, ids, values);

        for (uint256 i = 0; i < ids.length; i++) {
            if (from != address(0) && balanceOf(from, ids[i]) == 0) {
                _removeBondHolder(ids[i], from);
            }
            if (to != address(0) && holderIndex[ids[i]][to] == 0) {
                _addBondHolder(ids[i], to);
            }
        }
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
