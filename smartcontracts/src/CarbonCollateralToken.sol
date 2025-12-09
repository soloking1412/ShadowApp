// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title CarbonCollateralToken - COMPLETE PRODUCTION VERSION
 * @notice Tokenized carbon credits for ESG-linked infrastructure projects (ERC-721)
 */
contract CarbonCollateralToken is 
    Initializable,
    ERC721Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    enum CreditType {
        Renewable,
        Forestry,
        Industrial,
        Transportation,
        Agricultural,
        WasteManagement
    }
    
    enum VerificationStatus {
        Pending,
        Verified,
        Rejected,
        Retired
    }
    
    struct CarbonCredit {
        uint256 tokenId;
        CreditType creditType;
        uint256 tonnagesCO2;
        uint256 vintage;
        string projectName;
        string location;
        address issuer;
        uint256 issuanceDate;
        uint256 expiryDate;
        VerificationStatus status;
        address verifier;
        uint256 verificationDate;
        bytes32 certificationHash;
        bool retired;
        uint256 retirementDate;
    }
    
    struct Project {
        uint256 projectId;
        string name;
        string description;
        CreditType projectType;
        address owner;
        uint256 totalCredits;
        uint256 totalTonnages;
        bool active;
        bytes32 documentHash;
    }
    
    mapping(uint256 => CarbonCredit) public credits;
    mapping(uint256 => Project) public projects;
    mapping(address => uint256[]) public ownerCredits;
    mapping(uint256 => uint256[]) public projectCredits;
    
    uint256 public tokenCounter;
    uint256 public projectCounter;
    uint256 public totalTonnagesIssued;
    uint256 public totalTonnagesRetired;
    
    string private baseTokenURI;
    
    event CreditMinted(
        uint256 indexed tokenId,
        address indexed issuer,
        uint256 tonnagesCO2,
        CreditType creditType
    );
    event CreditVerified(uint256 indexed tokenId, address indexed verifier);
    event CreditRetired(uint256 indexed tokenId, address indexed owner, uint256 tonnagesCO2);
    event ProjectCreated(uint256 indexed projectId, string name, address indexed owner);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address admin,
        string memory name,
        string memory symbol,
        string memory baseURI
    ) public initializer {
        __ERC721_init(name, symbol);
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(VERIFIER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        baseTokenURI = baseURI;
    }
    
    function createProject(
        string memory name,
        string memory description,
        CreditType projectType,
        bytes32 documentHash
    ) external returns (uint256) {
        uint256 projectId = ++projectCounter;
        
        projects[projectId] = Project({
            projectId: projectId,
            name: name,
            description: description,
            projectType: projectType,
            owner: msg.sender,
            totalCredits: 0,
            totalTonnages: 0,
            active: true,
            documentHash: documentHash
        });
        
        emit ProjectCreated(projectId, name, msg.sender);
        
        return projectId;
    }
    
    function mintCredit(
        uint256 projectId,
        address to,
        CreditType creditType,
        uint256 tonnagesCO2,
        uint256 vintage,
        string memory projectName,
        string memory location,
        uint256 expiryDate,
        bytes32 certificationHash
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256) {
        require(to != address(0), "Invalid address");
        require(tonnagesCO2 > 0, "Invalid tonnage");
        require(projects[projectId].active, "Project not active");
        
        uint256 tokenId = ++tokenCounter;
        
        credits[tokenId] = CarbonCredit({
            tokenId: tokenId,
            creditType: creditType,
            tonnagesCO2: tonnagesCO2,
            vintage: vintage,
            projectName: projectName,
            location: location,
            issuer: msg.sender,
            issuanceDate: block.timestamp,
            expiryDate: expiryDate,
            status: VerificationStatus.Pending,
            verifier: address(0),
            verificationDate: 0,
            certificationHash: certificationHash,
            retired: false,
            retirementDate: 0
        });
        
        _safeMint(to, tokenId);
        
        ownerCredits[to].push(tokenId);
        projectCredits[projectId].push(tokenId);
        
        // Update project stats
        Project storage project = projects[projectId];
        project.totalCredits++;
        project.totalTonnages += tonnagesCO2;
        
        totalTonnagesIssued += tonnagesCO2;
        
        emit CreditMinted(tokenId, msg.sender, tonnagesCO2, creditType);
        
        return tokenId;
    }
    
    function verifyCredit(uint256 tokenId, bool approved) 
        external 
        onlyRole(VERIFIER_ROLE) 
    {
        CarbonCredit storage credit = credits[tokenId];
        require(credit.status == VerificationStatus.Pending, "Not pending");
        
        credit.status = approved ? VerificationStatus.Verified : VerificationStatus.Rejected;
        credit.verifier = msg.sender;
        credit.verificationDate = block.timestamp;
        
        emit CreditVerified(tokenId, msg.sender);
    }
    
    function retireCredit(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        
        CarbonCredit storage credit = credits[tokenId];
        require(credit.status == VerificationStatus.Verified, "Not verified");
        require(!credit.retired, "Already retired");
        require(block.timestamp < credit.expiryDate, "Expired");
        
        credit.retired = true;
        credit.retirementDate = block.timestamp;
        credit.status = VerificationStatus.Retired;
        
        totalTonnagesRetired += credit.tonnagesCO2;
        
        // Burn the token
        _burn(tokenId);
        
        emit CreditRetired(tokenId, msg.sender, credit.tonnagesCO2);
    }
    
    function batchRetireCredits(uint256[] memory tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            this.retireCredit(tokenIds[i]);
        }
    }
    
    function transferCredit(address to, uint256 tokenId) 
        external 
        whenNotPaused 
    {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        
        CarbonCredit storage credit = credits[tokenId];
        require(credit.status == VerificationStatus.Verified, "Not verified");
        require(!credit.retired, "Retired");
        require(block.timestamp < credit.expiryDate, "Expired");
        
        safeTransferFrom(msg.sender, to, tokenId);
        
        // Update owner credits
        ownerCredits[to].push(tokenId);
        _removeFromOwnerCredits(msg.sender, tokenId);
    }
    
    function _removeFromOwnerCredits(address owner, uint256 tokenId) internal {
        uint256[] storage ownerCreditsList = ownerCredits[owner];

        for (uint256 i = 0; i < ownerCreditsList.length; i++) {
            if (ownerCreditsList[i] == tokenId) {
                ownerCreditsList[i] = ownerCreditsList[ownerCreditsList.length - 1];
                ownerCreditsList.pop();
                break;
            }
        }
    }
    
    function deactivateProject(uint256 projectId) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        projects[projectId].active = false;
    }
    
    function setBaseURI(string memory baseURI) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        baseTokenURI = baseURI;
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    function getCredit(uint256 tokenId) 
        external 
        view 
        returns (CarbonCredit memory) 
    {
        return credits[tokenId];
    }
    
    function getProject(uint256 projectId) 
        external 
        view 
        returns (Project memory) 
    {
        return projects[projectId];
    }
    
    function getOwnerCredits(address owner) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return ownerCredits[owner];
    }
    
    function getProjectCredits(uint256 projectId) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return projectCredits[projectId];
    }
    
    function getTotalTonnages(address owner) 
        external 
        view 
        returns (uint256 total) 
    {
        uint256[] storage creditIds = ownerCredits[owner];
        
        for (uint256 i = 0; i < creditIds.length; i++) {
            CarbonCredit storage credit = credits[creditIds[i]];
            if (!credit.retired && credit.status == VerificationStatus.Verified) {
                total += credit.tonnagesCO2;
            }
        }
        
        return total;
    }
    
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }
    
    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        whenNotPaused
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}