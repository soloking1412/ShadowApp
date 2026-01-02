// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract FractionalReserveBanking is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    struct CountryReserve {
        string country;
        uint256 totalReserves;
        uint256 totalDeposits;
        uint256 totalLoans;
        uint256 reserveRatio;
        uint256 interestRate;
        bool active;
    }

    struct Deposit {
        uint256 depositId;
        address depositor;
        string country;
        uint256 amount;
        uint256 timestamp;
        uint256 maturityDate;
        uint256 interestRate;
        bool withdrawn;
    }

    struct Loan {
        uint256 loanId;
        address borrower;
        string country;
        uint256 principal;
        uint256 interestRate;
        uint256 timestamp;
        uint256 maturityDate;
        uint256 paidAmount;
        bool fullyPaid;
        address collateralToken;
        uint256 collateralTokenId;
        uint256 collateralAmount;
    }

    struct CountryHolding {
        string country;
        uint256 totalHoldings;
        uint256 availableForInvestment;
        uint256 activeInvestments;
        uint256 lastUpdate;
    }

    mapping(string => CountryReserve) public countryReserves;
    mapping(uint256 => Deposit) public deposits;
    mapping(uint256 => Loan) public loans;
    mapping(string => CountryHolding) public holdings;
    mapping(address => uint256[]) public userDeposits;
    mapping(address => uint256[]) public userLoans;
    mapping(address => mapping(string => uint256)) public lastDepositTime; // Flash loan protection

    string[] public countries;
    uint256 public depositCounter;
    uint256 public loanCounter;

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_RESERVE_RATIO = 1000;
    uint256 public constant MIN_DEPOSIT_LOCK_TIME = 1 hours; // Flash loan protection
    uint256 public globalReserveRatio;

    event ReserveInitialized(string country, uint256 reserveRatio);
    event DepositMade(uint256 indexed depositId, address indexed depositor, string country, uint256 amount);
    event LoanIssued(uint256 indexed loanId, address indexed borrower, string country, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, uint256 amount);
    event WithdrawalMade(uint256 indexed depositId, address indexed depositor, uint256 amount);

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, uint256 _globalReserveRatio) public initializer {
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        globalReserveRatio = _globalReserveRatio;

        _initializeCountries();
    }

    function _initializeCountries() internal {
        string[46] memory countryList = [
            "US", "GB", "DE", "FR", "JP", "CN", "AU", "CA", "RU",
            "ID", "MM", "TH", "SG", "EG", "LY", "LB", "PS", "JO",
            "BA", "SY", "AL", "BR", "GE", "DZ", "MA", "KR", "AM",
            "NG", "IN", "CL", "AR", "ZA", "TN", "CO", "VE", "BO",
            "MX", "SA", "QA", "KW", "OM", "YE", "IQ", "IR", "AE", "CH"
        ];

        for (uint256 i = 0; i < countryList.length; i++) {
            string memory country = countryList[i];
            countries.push(country);

            countryReserves[country] = CountryReserve({
                country: country,
                totalReserves: 0,
                totalDeposits: 0,
                totalLoans: 0,
                reserveRatio: globalReserveRatio,
                interestRate: 500,
                active: true
            });

            holdings[country] = CountryHolding({
                country: country,
                totalHoldings: 0,
                availableForInvestment: 0,
                activeInvestments: 0,
                lastUpdate: block.timestamp
            });

            emit ReserveInitialized(country, globalReserveRatio);
        }
    }

    function makeDeposit(
        string memory country,
        uint256 maturityDate,
        uint256 interestRate
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        require(countryReserves[country].active, "Country not active");
        require(msg.value > 0, "Invalid amount");
        require(maturityDate > block.timestamp, "Invalid maturity");

        CountryReserve storage reserve = countryReserves[country];
        uint256 depositId = depositCounter++;

        deposits[depositId] = Deposit({
            depositId: depositId,
            depositor: msg.sender,
            country: country,
            amount: msg.value,
            timestamp: block.timestamp,
            maturityDate: maturityDate,
            interestRate: interestRate,
            withdrawn: false
        });

        reserve.totalDeposits += msg.value;
        reserve.totalReserves += msg.value;

        holdings[country].totalHoldings += msg.value;
        holdings[country].availableForInvestment += (msg.value * (BASIS_POINTS - reserve.reserveRatio)) / BASIS_POINTS;
        holdings[country].lastUpdate = block.timestamp;

        userDeposits[msg.sender].push(depositId);

        // FLASH LOAN PROTECTION: Record deposit time
        lastDepositTime[msg.sender][country] = block.timestamp;

        emit DepositMade(depositId, msg.sender, country, msg.value);

        return depositId;
    }

    function issueLoan(
        string memory country,
        uint256 amount,
        uint256 maturityDate,
        address collateralToken,
        uint256 collateralTokenId,
        uint256 collateralAmount
    ) external nonReentrant whenNotPaused returns (uint256) {
        CountryReserve storage reserve = countryReserves[country];
        require(reserve.active, "Country not active");

        // FLASH LOAN PROTECTION: Prevent borrowing immediately after deposit
        require(
            block.timestamp >= lastDepositTime[msg.sender][country] + MIN_DEPOSIT_LOCK_TIME,
            "Must wait after deposit to borrow"
        );

        uint256 availableFunds = (reserve.totalDeposits * (BASIS_POINTS - reserve.reserveRatio)) / BASIS_POINTS - reserve.totalLoans;
        require(amount <= availableFunds, "Insufficient reserves");

        if (collateralToken != address(0)) {
            IERC1155(collateralToken).safeTransferFrom(msg.sender, address(this), collateralTokenId, collateralAmount, "");
        }

        uint256 loanId = loanCounter++;

        loans[loanId] = Loan({
            loanId: loanId,
            borrower: msg.sender,
            country: country,
            principal: amount,
            interestRate: reserve.interestRate,
            timestamp: block.timestamp,
            maturityDate: maturityDate,
            paidAmount: 0,
            fullyPaid: false,
            collateralToken: collateralToken,
            collateralTokenId: collateralTokenId,
            collateralAmount: collateralAmount
        });

        reserve.totalLoans += amount;
        holdings[country].availableForInvestment -= amount;
        holdings[country].activeInvestments += amount;
        holdings[country].lastUpdate = block.timestamp;

        userLoans[msg.sender].push(loanId);

        payable(msg.sender).transfer(amount);

        emit LoanIssued(loanId, msg.sender, country, amount);

        return loanId;
    }

    function repayLoan(uint256 loanId) external payable nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.borrower == msg.sender, "Not borrower");
        require(!loan.fullyPaid, "Already paid");

        uint256 totalOwed = loan.principal + ((loan.principal * loan.interestRate * (block.timestamp - loan.timestamp)) / (365 days * BASIS_POINTS));
        uint256 remaining = totalOwed - loan.paidAmount;

        require(msg.value <= remaining, "Overpayment");

        loan.paidAmount += msg.value;

        if (loan.paidAmount >= totalOwed) {
            loan.fullyPaid = true;

            CountryReserve storage reserve = countryReserves[loan.country];
            reserve.totalLoans -= loan.principal;

            holdings[loan.country].activeInvestments -= loan.principal;
            holdings[loan.country].availableForInvestment += loan.principal;
            holdings[loan.country].lastUpdate = block.timestamp;

            if (loan.collateralToken != address(0)) {
                IERC1155(loan.collateralToken).safeTransferFrom(
                    address(this),
                    msg.sender,
                    loan.collateralTokenId,
                    loan.collateralAmount,
                    ""
                );
            }
        }

        emit LoanRepaid(loanId, msg.value);
    }

    function withdraw(uint256 depositId) external nonReentrant {
        Deposit storage deposit = deposits[depositId];
        require(deposit.depositor == msg.sender, "Not depositor");
        require(!deposit.withdrawn, "Already withdrawn");
        require(block.timestamp >= deposit.maturityDate, "Not matured");

        CountryReserve storage reserve = countryReserves[deposit.country];

        uint256 interest = (deposit.amount * deposit.interestRate * (block.timestamp - deposit.timestamp)) / (365 days * BASIS_POINTS);
        uint256 totalAmount = deposit.amount + interest;

        require(reserve.totalReserves >= totalAmount, "Insufficient reserves");

        deposit.withdrawn = true;
        reserve.totalDeposits -= deposit.amount;
        reserve.totalReserves -= totalAmount;

        holdings[deposit.country].totalHoldings -= deposit.amount;
        holdings[deposit.country].lastUpdate = block.timestamp;

        payable(msg.sender).transfer(totalAmount);

        emit WithdrawalMade(depositId, msg.sender, totalAmount);
    }

    function updateReserveRatio(string memory country, uint256 newRatio) external onlyRole(OPERATOR_ROLE) {
        require(newRatio >= MIN_RESERVE_RATIO, "Below minimum");
        countryReserves[country].reserveRatio = newRatio;
    }

    function updateInterestRate(string memory country, uint256 newRate) external onlyRole(OPERATOR_ROLE) {
        require(newRate <= 2000, "Rate too high");
        countryReserves[country].interestRate = newRate;
    }

    function getCountryHolding(string memory country) external view returns (CountryHolding memory) {
        return holdings[country];
    }

    function getAllCountries() external view returns (string[] memory) {
        return countries;
    }

    function getUserDeposits(address user) external view returns (uint256[] memory) {
        return userDeposits[user];
    }

    function getUserLoans(address user) external view returns (uint256[] memory) {
        return userLoans[user];
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    receive() external payable {}
}

