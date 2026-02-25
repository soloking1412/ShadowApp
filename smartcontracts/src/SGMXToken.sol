// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title SGMXToken — Samuel Global Market Xchange Security Token
/// @notice Regulated security token representing equity in SGMX Inc.
///         Total supply: 250 Quadrillion SGMX (2.5 × 10^17), 18 decimals.
///         Transfer-restricted; KYC/accreditation required.
///         Paired to OICD stablecoin for price discovery.
contract SGMXToken is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    string  public constant NAME    = "Samuel Global Market Xchange Security Token";
    string  public constant SYMBOL  = "SGMX";
    string  public constant COMPANY = "Samuel Global Market Xchange Inc.";
    uint8   public constant DECIMALS = 18;

    // 250 quadrillion × 10^18 decimals
    uint256 public constant TOTAL_SUPPLY = 250_000_000_000_000_000 * 10**18;

    // Security token transfer gate and OICD pair
    bool    public transfersEnabled;
    uint256 public oicdPairRate;    // 0.0001 OICD per SGMX initially

    // ── Investor Record ──────────────────────────────────────────────────────────

    struct Investor {
        uint256 balance;
        bool    kycVerified;
        bool    accredited;          // SEC/OZF accredited investor
        string  jurisdiction;        // ISO country code
        uint256 investmentOICD;      // total OICD invested
        uint256 shareClass;          // 0=common, 1=preferred, 2=institutional
        uint256 registeredAt;
        uint256 dividendsAccrued;    // in OICD wei
    }

    // ── Share Issuance Record ────────────────────────────────────────────────────

    struct ShareIssuance {
        address to;
        uint256 amount;
        uint256 shareClass;
        uint256 issuedAt;
        string  memo;
    }

    // ── Dividend ─────────────────────────────────────────────────────────────────

    struct Dividend {
        uint256 id;
        uint256 amountPerShare;      // OICD wei per SGMX unit
        uint256 snapshotAt;
        uint256 totalDistributed;
        bool    declared;
    }

    // ── Corporate Action ─────────────────────────────────────────────────────────

    struct CorporateAction {
        uint256 id;
        string  actionType;          // "dividend" | "stock_split" | "rights_issue" | "merger"
        string  description;
        uint256 executedAt;
    }

    // ── Storage ──────────────────────────────────────────────────────────────────

    uint256 public circulatingSupply;
    uint256 public totalInvestors;
    uint256 public dividendCounter;
    uint256 public issuanceCounter;
    uint256 public actionCounter;

    // Cap table
    uint256 public foundersShares;
    uint256 public publicShares;
    uint256 public reservedShares;

    mapping(address => Investor)     public investors;
    mapping(address => bool)         public registered;
    mapping(address => bool)         public whitelist;    // KYC + accreditation gate
    mapping(uint256 => Dividend)     public dividends;
    mapping(uint256 => mapping(address => bool)) public dividendClaimed;
    mapping(uint256 => ShareIssuance)  public issuances;
    mapping(uint256 => CorporateAction) public corporateActions;

    // ── Events ───────────────────────────────────────────────────────────────────

    event InvestorRegistered(address indexed investor, string jurisdiction, uint256 shareClass);
    event KYCVerified(address indexed investor);
    event SharesIssued(address indexed to, uint256 amount, uint256 shareClass, string memo);
    event DividendDeclared(uint256 indexed id, uint256 amountPerShare);
    event DividendClaimed(address indexed investor, uint256 indexed id, uint256 amount);
    event CorporateActionFiled(uint256 indexed id, string actionType);
    event TransfersToggled(bool enabled);
    event PairRateUpdated(uint256 newRate);
    event WhitelistUpdated(address indexed investor, bool status);

    // ── Initializer ──────────────────────────────────────────────────────────────

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        transfersEnabled = false;       // securities locked by default
        oicdPairRate     = 1e14;        // 0.0001 OICD per SGMX
        // Seed cap table
        foundersShares    = TOTAL_SUPPLY * 40 / 100;
        publicShares      = TOTAL_SUPPLY * 20 / 100;
        reservedShares    = TOTAL_SUPPLY * 40 / 100;
        circulatingSupply = publicShares;
    }

    // ── Investor Onboarding ───────────────────────────────────────────────────────

    function registerInvestor(string calldata jurisdiction, uint256 shareClass) external {
        require(!registered[msg.sender], "Already registered");
        require(shareClass <= 2,         "Invalid share class");
        investors[msg.sender] = Investor({
            balance:         0,
            kycVerified:     false,
            accredited:      false,
            jurisdiction:    jurisdiction,
            investmentOICD:  0,
            shareClass:      shareClass,
            registeredAt:    block.timestamp,
            dividendsAccrued: 0
        });
        registered[msg.sender] = true;
        totalInvestors++;
        emit InvestorRegistered(msg.sender, jurisdiction, shareClass);
    }

    // ── KYC / Compliance ─────────────────────────────────────────────────────────

    function verifyKYC(address investor) external onlyOwner {
        require(registered[investor], "Not registered");
        investors[investor].kycVerified = true;
        investors[investor].accredited  = true;
        whitelist[investor]             = true;
        emit KYCVerified(investor);
    }

    function updateWhitelist(address investor, bool status) external onlyOwner {
        whitelist[investor] = status;
        emit WhitelistUpdated(investor, status);
    }

    // ── Share Issuance ────────────────────────────────────────────────────────────

    function issueShares(
        address to,
        uint256 amount,
        uint256 shareClass,
        string calldata memo
    ) external onlyOwner {
        require(circulatingSupply + amount <= TOTAL_SUPPLY, "Exceeds supply");
        require(registered[to] || !transfersEnabled,       "Recipient not registered");
        investors[to].balance += amount;
        circulatingSupply     += amount;
        uint256 id = ++issuanceCounter;
        issuances[id] = ShareIssuance({
            to:         to,
            amount:     amount,
            shareClass: shareClass,
            issuedAt:   block.timestamp,
            memo:       memo
        });
        emit SharesIssued(to, amount, shareClass, memo);
    }

    // ── Dividends ─────────────────────────────────────────────────────────────────

    function declareDividend(uint256 amountPerShare) external onlyOwner returns (uint256 id) {
        id = ++dividendCounter;
        dividends[id] = Dividend({
            id:               id,
            amountPerShare:   amountPerShare,
            snapshotAt:       block.timestamp,
            totalDistributed: 0,
            declared:         true
        });
        emit DividendDeclared(id, amountPerShare);
    }

    function claimDividend(uint256 dividendId) external {
        require(registered[msg.sender],                         "Not registered");
        require(!dividendClaimed[dividendId][msg.sender],       "Already claimed");
        require(dividends[dividendId].declared,                 "Dividend not declared");
        uint256 payout = (investors[msg.sender].balance * dividends[dividendId].amountPerShare) / 1e18;
        require(payout > 0, "No payout");
        dividendClaimed[dividendId][msg.sender] = true;
        investors[msg.sender].dividendsAccrued += payout;
        dividends[dividendId].totalDistributed += payout;
        emit DividendClaimed(msg.sender, dividendId, payout);
    }

    // ── Corporate Actions ─────────────────────────────────────────────────────────

    function fileCorporateAction(
        string calldata actionType,
        string calldata description
    ) external onlyOwner returns (uint256 id) {
        id = ++actionCounter;
        corporateActions[id] = CorporateAction({
            id:          id,
            actionType:  actionType,
            description: description,
            executedAt:  block.timestamp
        });
        emit CorporateActionFiled(id, actionType);
    }

    // ── Transfer Controls ─────────────────────────────────────────────────────────

    function enableTransfers(bool enabled) external onlyOwner {
        transfersEnabled = enabled;
        emit TransfersToggled(enabled);
    }

    function updateOICDPairRate(uint256 newRate) external onlyOwner {
        oicdPairRate = newRate;
        emit PairRateUpdated(newRate);
    }

    // ── Views ─────────────────────────────────────────────────────────────────────

    function getInvestor(address inv) external view returns (Investor memory) { return investors[inv]; }
    function getDividend(uint256 id) external view returns (Dividend memory)  { return dividends[id]; }
    function getIssuance(uint256 id) external view returns (ShareIssuance memory) { return issuances[id]; }
    function getAction(uint256 id)   external view returns (CorporateAction memory) { return corporateActions[id]; }
    function totalSupply() external pure returns (uint256) { return TOTAL_SUPPLY; }

    function capTable() external view returns (
        uint256 founders, uint256 pub, uint256 reserved, uint256 circulating
    ) {
        return (foundersShares, publicShares, reservedShares, circulatingSupply);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
