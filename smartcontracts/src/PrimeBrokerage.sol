// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PrimeBrokerage
 * @notice Prime brokerage services for institutional clients
 * @dev Covers margin lending, securities lending, custody, execution services
 */
contract PrimeBrokerage is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PRIME_BROKER_ROLE = keccak256("PRIME_BROKER_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");

    enum ClientTier {
        Institutional,
        HedgeFund,
        AssetManager,
        FamilyOffice,
        Sovereign
    }

    enum LoanStatus {
        Active,
        Closed,
        Defaulted,
        Restructured
    }

    enum CollateralType {
        Cash,
        Securities,
        Bonds,
        Commodities,
        RealEstate
    }

    struct PrimeClient {
        address clientAddress;
        string clientName;
        ClientTier tier;
        uint256 creditLimit;
        uint256 utilizedCredit;
        uint256 collateralValue;
        uint256 maintenanceMargin; // Basis points
        bool active;
        uint256 onboardedDate;
    }

    struct MarginLoan {
        uint256 loanId;
        address client;
        uint256 principal;
        uint256 interestRate; // Basis points
        uint256 outstanding;
        uint256 collateralValue;
        LoanStatus status;
        uint256 issuedDate;
        uint256 maturityDate;
        uint256 lastPaymentDate;
    }

    struct SecuritiesLending {
        uint256 lendingId;
        address lender;
        address borrower;
        string securityId; // ISIN or similar
        uint256 quantity;
        uint256 lendingFee; // Basis points
        uint256 collateralRequired;
        uint256 collateralPosted;
        uint256 startDate;
        uint256 endDate;
        bool returned;
    }

    struct CustodyAccount {
        address client;
        uint256 cashBalance;
        mapping(string => uint256) securities; // securityId => quantity
        string[] securityList;
        uint256 totalValue;
        bool segregated; // Segregated vs omnibus
    }

    struct ExecutionOrder {
        uint256 orderId;
        address client;
        string symbol;
        bool isBuy;
        uint256 quantity;
        uint256 limitPrice;
        uint256 executedPrice;
        uint256 executedQuantity;
        uint256 timestamp;
        bool completed;
    }

    struct RiskMetrics {
        address client;
        uint256 valueAtRisk; // Value at Risk
        uint256 leverage;
        uint256 concentration; // Basis points
        uint256 liquidityRatio;
        uint256 lastUpdated;
    }

    // State variables
    mapping(address => PrimeClient) public clients;
    mapping(uint256 => MarginLoan) public loans;
    mapping(uint256 => SecuritiesLending) public lendings;
    mapping(address => CustodyAccount) private custodyAccounts;
    mapping(uint256 => ExecutionOrder) public orders;
    mapping(address => RiskMetrics) public riskProfiles;

    address[] public clientList;
    uint256 public loanCounter;
    uint256 public lendingCounter;
    uint256 public orderCounter;

    uint256 public totalAssetsUnderCustody;
    uint256 public totalLoansOutstanding;
    uint256 public totalSecuritiesOnLoan;
    uint256 public constant BASIS_POINTS = 10000;

    // Events
    event ClientOnboarded(
        address indexed client,
        ClientTier tier,
        uint256 creditLimit
    );

    event MarginLoanIssued(
        uint256 indexed loanId,
        address indexed client,
        uint256 principal,
        uint256 interestRate
    );

    event SecurityLent(
        uint256 indexed lendingId,
        address indexed lender,
        address indexed borrower,
        string securityId,
        uint256 quantity
    );

    event OrderExecuted(
        uint256 indexed orderId,
        address indexed client,
        string symbol,
        uint256 executedPrice,
        uint256 quantity
    );

    event MarginCall(
        address indexed client,
        uint256 requiredCollateral,
        uint256 currentCollateral
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(PRIME_BROKER_ROLE, admin);
        _grantRole(RISK_MANAGER_ROLE, admin);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(ADMIN_ROLE)
    {}

    /**
     * @notice Onboard prime client
     */
    function onboardClient(
        address clientAddress,
        string memory clientName,
        ClientTier tier,
        uint256 creditLimit,
        uint256 maintenanceMargin
    ) external onlyRole(PRIME_BROKER_ROLE) {
        require(!clients[clientAddress].active, "Client already exists");
        require(maintenanceMargin >= 2500, "Minimum 25% margin required");

        clients[clientAddress] = PrimeClient({
            clientAddress: clientAddress,
            clientName: clientName,
            tier: tier,
            creditLimit: creditLimit,
            utilizedCredit: 0,
            collateralValue: 0,
            maintenanceMargin: maintenanceMargin,
            active: true,
            onboardedDate: block.timestamp
        });

        clientList.push(clientAddress);

        emit ClientOnboarded(clientAddress, tier, creditLimit);
    }

    /**
     * @notice Issue margin loan
     */
    function issueMarginLoan(
        address client,
        uint256 principal,
        uint256 interestRate,
        uint256 collateralValue,
        uint256 maturityDate
    ) external onlyRole(PRIME_BROKER_ROLE) whenNotPaused returns (uint256) {
        PrimeClient storage primeClient = clients[client];
        require(primeClient.active, "Client not active");
        require(primeClient.utilizedCredit + principal <= primeClient.creditLimit, "Exceeds credit limit");
        require(collateralValue >= (principal * primeClient.maintenanceMargin) / BASIS_POINTS, "Insufficient collateral");

        uint256 loanId = ++loanCounter;

        loans[loanId] = MarginLoan({
            loanId: loanId,
            client: client,
            principal: principal,
            interestRate: interestRate,
            outstanding: principal,
            collateralValue: collateralValue,
            status: LoanStatus.Active,
            issuedDate: block.timestamp,
            maturityDate: maturityDate,
            lastPaymentDate: block.timestamp
        });

        primeClient.utilizedCredit += principal;
        primeClient.collateralValue += collateralValue;
        totalLoansOutstanding += principal;

        emit MarginLoanIssued(loanId, client, principal, interestRate);

        return loanId;
    }

    /**
     * @notice Lend securities
     */
    function lendSecurities(
        address borrower,
        string memory securityId,
        uint256 quantity,
        uint256 lendingFee,
        uint256 collateralRequired,
        uint256 duration
    ) external whenNotPaused returns (uint256) {
        require(clients[msg.sender].active, "Lender not prime client");
        require(clients[borrower].active, "Borrower not prime client");

        uint256 lendingId = ++lendingCounter;

        lendings[lendingId] = SecuritiesLending({
            lendingId: lendingId,
            lender: msg.sender,
            borrower: borrower,
            securityId: securityId,
            quantity: quantity,
            lendingFee: lendingFee,
            collateralRequired: collateralRequired,
            collateralPosted: 0,
            startDate: block.timestamp,
            endDate: block.timestamp + duration,
            returned: false
        });

        totalSecuritiesOnLoan += quantity;

        emit SecurityLent(lendingId, msg.sender, borrower, securityId, quantity);

        return lendingId;
    }

    /**
     * @notice Execute trade order
     */
    function executeOrder(
        address client,
        string memory symbol,
        bool isBuy,
        uint256 quantity,
        uint256 limitPrice
    ) external onlyRole(PRIME_BROKER_ROLE) returns (uint256) {
        require(clients[client].active, "Client not active");

        uint256 orderId = ++orderCounter;

        orders[orderId] = ExecutionOrder({
            orderId: orderId,
            client: client,
            symbol: symbol,
            isBuy: isBuy,
            quantity: quantity,
            limitPrice: limitPrice,
            executedPrice: limitPrice,
            executedQuantity: quantity,
            timestamp: block.timestamp,
            completed: true
        });

        emit OrderExecuted(orderId, client, symbol, limitPrice, quantity);

        return orderId;
    }

    /**
     * @notice Deposit collateral
     */
    function depositCollateral(address client)
        external
        payable
        whenNotPaused
    {
        require(clients[client].active, "Client not active");

        PrimeClient storage primeClient = clients[client];
        primeClient.collateralValue += msg.value;
    }

    /**
     * @notice Check margin requirement
     */
    function checkMargin(address client)
        external
        onlyRole(RISK_MANAGER_ROLE)
    {
        PrimeClient storage primeClient = clients[client];
        require(primeClient.active, "Client not active");

        uint256 requiredCollateral = (primeClient.utilizedCredit * primeClient.maintenanceMargin) / BASIS_POINTS;

        if (primeClient.collateralValue < requiredCollateral) {
            emit MarginCall(client, requiredCollateral, primeClient.collateralValue);
        }
    }

    /**
     * @notice Update risk metrics
     */
    function updateRiskMetrics(
        address client,
        uint256 valueAtRisk,
        uint256 leverage,
        uint256 concentration,
        uint256 liquidityRatio
    ) external onlyRole(RISK_MANAGER_ROLE) {
        riskProfiles[client] = RiskMetrics({
            client: client,
            valueAtRisk: valueAtRisk,
            leverage: leverage,
            concentration: concentration,
            liquidityRatio: liquidityRatio,
            lastUpdated: block.timestamp
        });
    }

    /**
     * @notice Repay margin loan
     */
    function repayLoan(uint256 loanId)
        external
        payable
        nonReentrant
    {
        MarginLoan storage loan = loans[loanId];
        require(loan.client == msg.sender, "Not loan owner");
        require(loan.status == LoanStatus.Active, "Loan not active");
        require(msg.value <= loan.outstanding, "Exceeds outstanding");

        loan.outstanding -= msg.value;
        loan.lastPaymentDate = block.timestamp;

        PrimeClient storage client = clients[msg.sender];
        client.utilizedCredit -= msg.value;
        totalLoansOutstanding -= msg.value;

        if (loan.outstanding == 0) {
            loan.status = LoanStatus.Closed;
        }
    }

    /**
     * @notice Get client portfolio value
     */
    function getClientPortfolio(address client)
        external
        view
        returns (
            uint256 creditLimit,
            uint256 utilizedCredit,
            uint256 availableCredit,
            uint256 collateralValue,
            uint256 maintenanceMargin
        )
    {
        PrimeClient storage primeClient = clients[client];
        return (
            primeClient.creditLimit,
            primeClient.utilizedCredit,
            primeClient.creditLimit - primeClient.utilizedCredit,
            primeClient.collateralValue,
            primeClient.maintenanceMargin
        );
    }

    /**
     * @notice Get all clients
     */
    function getAllClients() external view returns (address[] memory) {
        return clientList;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    receive() external payable {}
}
