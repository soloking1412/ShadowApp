// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract OGRBlacklist is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    enum EntityType { Address, Country, Company, Market, Government }
    enum RestrictionLevel { None, Warning, SoftBan, HardBan, Permanent }

    struct BlacklistEntry {
        EntityType entityType;
        RestrictionLevel level;
        string reason;
        uint256 addedAt;
        uint256 expiresAt;
        string[] references;
        bool active;
    }

    mapping(address => BlacklistEntry) public blacklistedAddresses;
    mapping(string => BlacklistEntry) public blacklistedCountries;
    mapping(string => BlacklistEntry) public blacklistedCompanies;
    mapping(string => BlacklistEntry) public blacklistedMarkets;
    mapping(string => BlacklistEntry) public blacklistedGovernments;

    address[] public blacklistedAddressList;
    string[] public blacklistedCountryList;
    string[] public blacklistedCompanyList;

    event EntityBlacklisted(EntityType entityType, string identifier, RestrictionLevel level, string reason);
    event EntityRemovedFromBlacklist(EntityType entityType, string identifier);
    event AddressBlacklisted(address indexed addr, RestrictionLevel level, string reason);

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_OFFICER_ROLE, admin);
        _grantRole(AUDITOR_ROLE, admin);
    }

    function addToBlacklist(
        EntityType entityType,
        string memory identifier,
        RestrictionLevel level,
        string memory reason,
        uint256 duration,
        string[] memory references
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) whenNotPaused {
        require(level != RestrictionLevel.None, "Invalid level");

        uint256 expiresAt = duration > 0 ? block.timestamp + duration : 0;

        BlacklistEntry memory entry = BlacklistEntry({
            entityType: entityType,
            level: level,
            reason: reason,
            addedAt: block.timestamp,
            expiresAt: expiresAt,
            references: references,
            active: true
        });

        if (entityType == EntityType.Country) {
            if (bytes(blacklistedCountries[identifier].reason).length == 0) {
                blacklistedCountryList.push(identifier);
            }
            blacklistedCountries[identifier] = entry;
        } else if (entityType == EntityType.Company) {
            if (bytes(blacklistedCompanies[identifier].reason).length == 0) {
                blacklistedCompanyList.push(identifier);
            }
            blacklistedCompanies[identifier] = entry;
        } else if (entityType == EntityType.Market) {
            blacklistedMarkets[identifier] = entry;
        } else if (entityType == EntityType.Government) {
            blacklistedGovernments[identifier] = entry;
        }

        emit EntityBlacklisted(entityType, identifier, level, reason);
    }

    function addAddressToBlacklist(
        address addr,
        RestrictionLevel level,
        string memory reason,
        uint256 duration
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) whenNotPaused {
        require(level != RestrictionLevel.None, "Invalid level");
        require(addr != address(0), "Invalid address");

        if (!blacklistedAddresses[addr].active) {
            blacklistedAddressList.push(addr);
        }

        blacklistedAddresses[addr] = BlacklistEntry({
            entityType: EntityType.Address,
            level: level,
            reason: reason,
            addedAt: block.timestamp,
            expiresAt: duration > 0 ? block.timestamp + duration : 0,
            references: new string[](0),
            active: true
        });

        emit AddressBlacklisted(addr, level, reason);
    }

    function isBlacklisted(address addr) external view returns (bool, RestrictionLevel) {
        BlacklistEntry storage entry = blacklistedAddresses[addr];
        if (!entry.active) return (false, RestrictionLevel.None);
        if (entry.expiresAt > 0 && block.timestamp > entry.expiresAt) return (false, RestrictionLevel.None);
        return (true, entry.level);
    }

    function isCountryBlacklisted(string memory country) external view returns (bool, RestrictionLevel) {
        BlacklistEntry storage entry = blacklistedCountries[country];
        if (!entry.active) return (false, RestrictionLevel.None);
        if (entry.expiresAt > 0 && block.timestamp > entry.expiresAt) return (false, RestrictionLevel.None);
        return (true, entry.level);
    }

    function isCompanyBlacklisted(string memory company) external view returns (bool, RestrictionLevel) {
        BlacklistEntry storage entry = blacklistedCompanies[company];
        if (!entry.active) return (false, RestrictionLevel.None);
        if (entry.expiresAt > 0 && block.timestamp > entry.expiresAt) return (false, RestrictionLevel.None);
        return (true, entry.level);
    }

    function isMarketBlacklisted(string memory market) external view returns (bool, RestrictionLevel) {
        BlacklistEntry storage entry = blacklistedMarkets[market];
        if (!entry.active) return (false, RestrictionLevel.None);
        if (entry.expiresAt > 0 && block.timestamp > entry.expiresAt) return (false, RestrictionLevel.None);
        return (true, entry.level);
    }

    function isGovernmentBlacklisted(string memory government) external view returns (bool, RestrictionLevel) {
        BlacklistEntry storage entry = blacklistedGovernments[government];
        if (!entry.active) return (false, RestrictionLevel.None);
        if (entry.expiresAt > 0 && block.timestamp > entry.expiresAt) return (false, RestrictionLevel.None);
        return (true, entry.level);
    }

    function removeFromBlacklist(EntityType entityType, string memory identifier)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (entityType == EntityType.Country) {
            blacklistedCountries[identifier].active = false;
        } else if (entityType == EntityType.Company) {
            blacklistedCompanies[identifier].active = false;
        } else if (entityType == EntityType.Market) {
            blacklistedMarkets[identifier].active = false;
        } else if (entityType == EntityType.Government) {
            blacklistedGovernments[identifier].active = false;
        }

        emit EntityRemovedFromBlacklist(entityType, identifier);
    }

    function removeAddressFromBlacklist(address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        blacklistedAddresses[addr].active = false;
        emit EntityRemovedFromBlacklist(EntityType.Address, _addressToString(addr));
    }

    function getBlacklistedAddressCount() external view returns (uint256) {
        return blacklistedAddressList.length;
    }

    function getBlacklistedCountryCount() external view returns (uint256) {
        return blacklistedCountryList.length;
    }

    function getBlacklistedCompanyCount() external view returns (uint256) {
        return blacklistedCompanyList.length;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function _addressToString(address addr) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory data = abi.encodePacked(addr);
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint256 i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint8(data[i] >> 4)];
            str[3+i*2] = alphabet[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }
}
