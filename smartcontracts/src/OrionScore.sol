// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title OrionScore — 9-Variable LIFO Country Investment Algorithm
/// @notice Implements Obsidian Capital's Orion Algorithm for scoring sovereign
///         investment viability. Variables processed via LIFO (Last In First Out):
///         Systemic → Cashflow → Financial → EPS → Credit → Dividend → Banking → Inflation → Currency
///
///         Each variable scored 0–100. Composite score determines investment allocation tier.
contract OrionScore is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    // LIFO order — Systemic is first evaluated (index 8 = last in list)
    enum Variable {
        Currency,   // 0 — final assessment of overall environment
        Inflation,  // 1 — high inflation = opportunity for OICD stabilization
        Banking,    // 2 — local banking network effects
        Dividend,   // 3 — company dividend health
        Credit,     // 4 — borrowing activity and credit markets
        EPS,        // 5 — earnings per share of target companies
        Financial,  // 6 — ability to maintain credit and liquidity
        Cashflow,   // 7 — capital flow within country
        Systemic    // 8 — systemic risk, the "plumbing" check (evaluated first in LIFO)
    }

    struct VariableScore {
        uint8 score;       // 0–100
        string rationale;  // analyst note
        uint256 updatedAt;
    }

    struct CountryScore {
        string  name;
        string  code;           // ISO-2
        uint8[9] scores;        // Variable enum index → score
        string[9] rationales;
        uint256 compositeScore; // weighted aggregate 0–100
        uint256 lastUpdated;
        bool    approved;       // approved for Obsidian FDI
        uint256 allocationTier; // 1=basic, 2=standard, 3=premium, 4=sovereign
        uint256 debtMultiplier; // 150–450 (1.5x–4.5x)
        bool    exists;
    }

    struct ScoreHistory {
        uint256 timestamp;
        uint256 compositeScore;
        address analyst;
    }

    // Weights for composite (sum = 100)
    // Systemic=25, Cashflow=15, Financial=12, EPS=10, Credit=12, Dividend=8, Banking=8, Inflation=5, Currency=5
    uint8[9] public weights;

    uint256 public countryCount;
    mapping(string => CountryScore) public countryScores;  // code => score
    mapping(string => ScoreHistory[]) public history;
    mapping(address => bool) public analysts;
    string[] public registeredCountries;

    event CountryScored(string indexed countryCode, uint256 compositeScore, bool approved);
    event VariableUpdated(string indexed countryCode, Variable variable, uint8 score);
    event AnalystAuthorized(address analyst, bool status);
    event AllocationTierSet(string indexed countryCode, uint256 tier, uint256 multiplier);

    modifier onlyAnalyst() {
        require(analysts[msg.sender] || msg.sender == owner(), "Not authorized analyst");
        _;
    }

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        // Set variable weights (indices match Variable enum)
        weights[uint8(Variable.Currency)]   = 5;
        weights[uint8(Variable.Inflation)]  = 5;
        weights[uint8(Variable.Banking)]    = 8;
        weights[uint8(Variable.Dividend)]   = 8;
        weights[uint8(Variable.Credit)]     = 12;
        weights[uint8(Variable.EPS)]        = 10;
        weights[uint8(Variable.Financial)]  = 12;
        weights[uint8(Variable.Cashflow)]   = 15;
        weights[uint8(Variable.Systemic)]   = 25;

        // Seed emerging market countries with initial inflation-based scores
        _seedEmergingMarkets();
    }

    function _seedEmergingMarkets() internal {
        _registerCountry("LK", "Sri Lanka");
        _registerCountry("VE", "Venezuela");
        _registerCountry("SD", "Sudan");
        _registerCountry("ZW", "Zimbabwe");
        _registerCountry("AR", "Argentina");
        _registerCountry("SS", "South Sudan");
        _registerCountry("IR", "Iran");
        _registerCountry("ET", "Ethiopia");
        _registerCountry("AO", "Angola");
        _registerCountry("YE", "Yemen");
        _registerCountry("LY", "Libya");
        _registerCountry("TR", "Turkey");
        _registerCountry("NG", "Nigeria");
        _registerCountry("HT", "Haiti");
        _registerCountry("BR", "Brazil");
        _registerCountry("BY", "Belarus");
        _registerCountry("GH", "Ghana");
        _registerCountry("PK", "Pakistan");
        _registerCountry("BD", "Bangladesh");
        _registerCountry("MX", "Mexico");
    }

    function _registerCountry(string memory code, string memory name) internal {
        if (!countryScores[code].exists) {
            countryScores[code].name = name;
            countryScores[code].code = code;
            countryScores[code].exists = true;
            countryScores[code].lastUpdated = block.timestamp;
            registeredCountries.push(code);
            countryCount++;
        }
    }

    // -- Analyst Management --

    function authorizeAnalyst(address analyst, bool status) external onlyOwner {
        analysts[analyst] = status;
        emit AnalystAuthorized(analyst, status);
    }

    function registerCountry(string calldata code, string calldata name) external onlyOwner {
        _registerCountry(code, name);
    }

    // -- Scoring -- (LIFO: submit from Systemic down to Currency)

    function scoreCountry(
        string calldata code,
        uint8[9] calldata scores,  // indexed by Variable enum
        string[9] calldata rationales
    ) external onlyAnalyst {
        require(countryScores[code].exists, "Country not registered");

        CountryScore storage c = countryScores[code];
        uint256 composite = 0;

        for (uint8 i = 0; i < 9; i++) {
            require(scores[i] <= 100, "Score 0-100");
            c.scores[i] = scores[i];
            c.rationales[i] = rationales[i];
            composite += uint256(scores[i]) * uint256(weights[i]);
        }
        composite /= 100; // normalize weights (they sum to 100)
        c.compositeScore = composite;
        c.lastUpdated = block.timestamp;

        // Auto-determine approval (score >= 45 = approved for FDI)
        c.approved = composite >= 45;

        // Determine allocation tier and multiplier
        if (composite >= 75) {
            c.allocationTier = 4; c.debtMultiplier = 450; // 4.5x sovereign
        } else if (composite >= 60) {
            c.allocationTier = 3; c.debtMultiplier = 350; // 3.5x premium
        } else if (composite >= 45) {
            c.allocationTier = 2; c.debtMultiplier = 250; // 2.5x standard
        } else {
            c.allocationTier = 1; c.debtMultiplier = 150; // 1.5x basic (watch list)
        }

        history[code].push(ScoreHistory({
            timestamp: block.timestamp,
            compositeScore: composite,
            analyst: msg.sender
        }));

        emit CountryScored(code, composite, c.approved);
        emit AllocationTierSet(code, c.allocationTier, c.debtMultiplier);
    }

    function updateVariable(
        string calldata code,
        Variable variable,
        uint8 score,
        string calldata rationale
    ) external onlyAnalyst {
        require(countryScores[code].exists, "Country not registered");
        require(score <= 100, "Score 0-100");

        CountryScore storage c = countryScores[code];
        c.scores[uint8(variable)] = score;
        c.rationales[uint8(variable)] = rationale;

        // Recompute composite
        uint256 composite = 0;
        for (uint8 i = 0; i < 9; i++) {
            composite += uint256(c.scores[i]) * uint256(weights[i]);
        }
        composite /= 100;
        c.compositeScore = composite;
        c.approved = composite >= 45;
        c.lastUpdated = block.timestamp;

        emit VariableUpdated(code, variable, score);
        emit CountryScored(code, composite, c.approved);
    }

    // -- Views --

    function getCountryScore(string calldata code) external view returns (CountryScore memory) {
        return countryScores[code];
    }

    function getVariableScore(string calldata code, Variable variable) external view
        returns (uint8 score, string memory rationale, uint256 updatedAt)
    {
        CountryScore storage c = countryScores[code];
        uint8 idx = uint8(variable);
        return (c.scores[idx], c.rationales[idx], c.lastUpdated);
    }

    function getScoreHistory(string calldata code) external view returns (ScoreHistory[] memory) {
        return history[code];
    }

    function getAllCountries() external view returns (string[] memory) {
        return registeredCountries;
    }

    function getApprovedCountries() external view returns (string[] memory approved) {
        uint256 count = 0;
        for (uint256 i = 0; i < registeredCountries.length; i++) {
            if (countryScores[registeredCountries[i]].approved) count++;
        }
        approved = new string[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < registeredCountries.length; i++) {
            if (countryScores[registeredCountries[i]].approved) {
                approved[idx++] = registeredCountries[i];
            }
        }
    }

    function getWeights() external view returns (uint8[9] memory) {
        return weights;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
