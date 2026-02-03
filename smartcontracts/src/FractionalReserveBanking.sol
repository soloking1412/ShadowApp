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

    // IBAN Banking System
    struct IBANAccount {
        bytes2 countryCode;
        bytes4 bankCode;
        address owner;
        uint256 balance;
        uint256 creditLine;
        uint256 creditUsed;
        uint256 lastActivity;
        bool active;
    }

    // IBAN Mappings
    mapping(bytes32 => IBANAccount) public ibanAccounts;
    mapping(address => bytes32) public addressToIBAN;
    mapping(bytes2 => bool) public supportedCountryCodes;

    // Treasury for fee collection
    address public treasuryAddress;

    // IBAN Transfer fee: 0.009% = 9 basis points out of 100,000
    uint256 public constant TRANSFER_FEE_BPS = 9;
    uint256 public constant FEE_DENOMINATOR = 100000;

    // Credit limits based on Global Debt Index
    uint256 public globalDebtIndex; // Maximum credit multiplier (e.g., 200 = 2x balance)

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

    // IBAN Events
    event IBANRegistered(bytes32 indexed ibanHash, address indexed owner, bytes2 countryCode, bytes4 bankCode);
    event IBANDeposit(bytes32 indexed ibanHash, address indexed depositor, uint256 amount);
    event InterBankTransfer(bytes32 indexed fromIBAN, bytes32 indexed toIBAN, uint256 amount, uint256 fee);
    event CreditIssued(bytes32 indexed ibanHash, uint256 amount, uint256 newCreditLine);
    event CreditRepaid(bytes32 indexed ibanHash, uint256 amount, uint256 remainingDebt);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

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
        globalDebtIndex = 200; // Default 2x credit multiplier

        _initializeCountries();
        _initializeSupportedCountryCodes();
    }

    /**
     * @notice Initialize supported country codes for IBAN
     */
    function _initializeSupportedCountryCodes() internal {
        // Major country codes
        supportedCountryCodes[bytes2("US")] = true;
        supportedCountryCodes[bytes2("GB")] = true;
        supportedCountryCodes[bytes2("DE")] = true;
        supportedCountryCodes[bytes2("FR")] = true;
        supportedCountryCodes[bytes2("JP")] = true;
        supportedCountryCodes[bytes2("CN")] = true;
        supportedCountryCodes[bytes2("AU")] = true;
        supportedCountryCodes[bytes2("CA")] = true;
        supportedCountryCodes[bytes2("CH")] = true;
        supportedCountryCodes[bytes2("SG")] = true;
        supportedCountryCodes[bytes2("AE")] = true;
        supportedCountryCodes[bytes2("SA")] = true;
        supportedCountryCodes[bytes2("RU")] = true;
        supportedCountryCodes[bytes2("IN")] = true;
        supportedCountryCodes[bytes2("BR")] = true;
        supportedCountryCodes[bytes2("MX")] = true;
        supportedCountryCodes[bytes2("ZA")] = true;
        supportedCountryCodes[bytes2("NG")] = true;
        supportedCountryCodes[bytes2("EG")] = true;
        supportedCountryCodes[bytes2("KR")] = true;
        // OZF (Ozhumanill Zayed Federation) - custom code
        supportedCountryCodes[bytes2("OZ")] = true;
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

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

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

        (bool success, ) = payable(msg.sender).call{value: totalAmount}("");
        require(success, "Transfer failed");

        emit WithdrawalMade(depositId, msg.sender, totalAmount);
    }

    // ============ IBAN BANKING SYSTEM ============

    /**
     * @notice Set the treasury address for fee collection
     * @param _treasury Address of the treasury contract
     */
    function setTreasury(address _treasury) external onlyRole(ADMIN_ROLE) {
        require(_treasury != address(0), "Invalid treasury address");
        address oldTreasury = treasuryAddress;
        treasuryAddress = _treasury;
        emit TreasuryUpdated(oldTreasury, _treasury);
    }

    /**
     * @notice Add or remove supported country code
     * @param countryCode Two-letter country code
     * @param supported Whether the country is supported
     */
    function setSupportedCountryCode(bytes2 countryCode, bool supported) external onlyRole(ADMIN_ROLE) {
        supportedCountryCodes[countryCode] = supported;
    }

    /**
     * @notice Register a new IBAN for the caller
     * @param countryCode Two-letter country code (e.g., "GB", "US")
     * @param bankCode Four-character bank identifier
     * @return ibanHash The generated IBAN hash identifier
     */
    function registerIBAN(
        bytes2 countryCode,
        bytes4 bankCode
    ) external whenNotPaused returns (bytes32 ibanHash) {
        require(supportedCountryCodes[countryCode], "Country code not supported");
        require(addressToIBAN[msg.sender] == bytes32(0), "Already has IBAN");
        require(bankCode != bytes4(0), "Invalid bank code");

        // Generate IBAN hash: keccak256(countryCode + bankCode + address)
        ibanHash = keccak256(abi.encodePacked(countryCode, bankCode, msg.sender));

        require(!ibanAccounts[ibanHash].active, "IBAN already exists");

        ibanAccounts[ibanHash] = IBANAccount({
            countryCode: countryCode,
            bankCode: bankCode,
            owner: msg.sender,
            balance: 0,
            creditLine: 0,
            creditUsed: 0,
            lastActivity: block.timestamp,
            active: true
        });

        addressToIBAN[msg.sender] = ibanHash;

        emit IBANRegistered(ibanHash, msg.sender, countryCode, bankCode);
    }

    /**
     * @notice Deposit funds to caller's IBAN account
     */
    function depositToIBAN() external payable nonReentrant whenNotPaused {
        bytes32 ibanHash = addressToIBAN[msg.sender];
        require(ibanHash != bytes32(0), "No IBAN registered");
        require(msg.value > 0, "Invalid deposit amount");

        IBANAccount storage account = ibanAccounts[ibanHash];
        require(account.active, "IBAN inactive");

        account.balance += msg.value;
        account.lastActivity = block.timestamp;

        emit IBANDeposit(ibanHash, msg.sender, msg.value);
    }

    /**
     * @notice Withdraw funds from caller's IBAN account
     * @param amount Amount to withdraw
     */
    function withdrawFromIBAN(uint256 amount) external nonReentrant whenNotPaused {
        bytes32 ibanHash = addressToIBAN[msg.sender];
        require(ibanHash != bytes32(0), "No IBAN registered");

        IBANAccount storage account = ibanAccounts[ibanHash];
        require(account.active, "IBAN inactive");
        require(account.balance >= amount, "Insufficient balance");

        account.balance -= amount;
        account.lastActivity = block.timestamp;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @notice Transfer funds between IBAN accounts with 0.009% fee
     * @param toIBAN Recipient's IBAN hash
     * @param amount Amount to transfer (gross, before fee)
     */
    function interBankTransfer(
        bytes32 toIBAN,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        bytes32 fromIBAN = addressToIBAN[msg.sender];
        require(fromIBAN != bytes32(0), "Sender has no IBAN");
        require(toIBAN != bytes32(0), "Invalid recipient IBAN");
        require(fromIBAN != toIBAN, "Cannot transfer to self");

        IBANAccount storage sender = ibanAccounts[fromIBAN];
        IBANAccount storage recipient = ibanAccounts[toIBAN];

        require(sender.active, "Sender IBAN inactive");
        require(recipient.active, "Recipient IBAN inactive");
        require(sender.balance >= amount, "Insufficient balance");
        require(amount > 0, "Invalid amount");

        // Calculate 0.009% fee (9 / 100000)
        uint256 fee = (amount * TRANSFER_FEE_BPS) / FEE_DENOMINATOR;
        uint256 netAmount = amount - fee;

        // Update balances
        sender.balance -= amount;
        recipient.balance += netAmount;

        sender.lastActivity = block.timestamp;
        recipient.lastActivity = block.timestamp;

        // Send fee to Treasury
        if (fee > 0 && treasuryAddress != address(0)) {
            (bool feeSuccess, ) = payable(treasuryAddress).call{value: fee}("");
            require(feeSuccess, "Fee transfer failed");
        }

        emit InterBankTransfer(fromIBAN, toIBAN, amount, fee);
    }

    /**
     * @notice Issue credit line to an IBAN account (under-collateralized)
     * @param ibanHash The IBAN to issue credit to
     * @param amount Credit amount to issue
     */
    function issueCredit(
        bytes32 ibanHash,
        uint256 amount
    ) external onlyRole(OPERATOR_ROLE) {
        IBANAccount storage account = ibanAccounts[ibanHash];
        require(account.active, "IBAN inactive");
        require(amount > 0, "Invalid credit amount");

        // Check Global Debt Index limit: max credit = balance * (GDI / 100)
        uint256 maxCredit = (account.balance * globalDebtIndex) / 100;
        require(
            account.creditLine + amount <= maxCredit,
            "Exceeds GDI credit limit"
        );

        account.creditLine += amount;

        emit CreditIssued(ibanHash, amount, account.creditLine);
    }

    /**
     * @notice Use credit from IBAN account
     * @param amount Amount of credit to use
     */
    function useCredit(uint256 amount) external nonReentrant whenNotPaused {
        bytes32 ibanHash = addressToIBAN[msg.sender];
        require(ibanHash != bytes32(0), "No IBAN registered");

        IBANAccount storage account = ibanAccounts[ibanHash];
        require(account.active, "IBAN inactive");

        uint256 availableCredit = account.creditLine - account.creditUsed;
        require(amount <= availableCredit, "Insufficient credit");

        account.creditUsed += amount;
        account.lastActivity = block.timestamp;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Credit disbursement failed");
    }

    /**
     * @notice Repay used credit
     */
    function repayCredit() external payable nonReentrant {
        bytes32 ibanHash = addressToIBAN[msg.sender];
        require(ibanHash != bytes32(0), "No IBAN registered");

        IBANAccount storage account = ibanAccounts[ibanHash];
        require(account.creditUsed > 0, "No credit to repay");
        require(msg.value > 0, "Invalid repayment amount");

        uint256 repayAmount = msg.value > account.creditUsed ? account.creditUsed : msg.value;
        account.creditUsed -= repayAmount;
        account.lastActivity = block.timestamp;

        // Refund excess payment
        if (msg.value > repayAmount) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - repayAmount}("");
            require(success, "Refund failed");
        }

        emit CreditRepaid(ibanHash, repayAmount, account.creditUsed);
    }

    /**
     * @notice Update the Global Debt Index
     * @param newGDI New GDI value (e.g., 200 = 2x multiplier)
     */
    function setGlobalDebtIndex(uint256 newGDI) external onlyRole(ADMIN_ROLE) {
        require(newGDI >= 100 && newGDI <= 500, "GDI must be between 100-500");
        globalDebtIndex = newGDI;
    }

    /**
     * @notice Get IBAN account details by hash
     * @param ibanHash The IBAN hash to query
     */
    function getIBANAccount(bytes32 ibanHash) external view returns (IBANAccount memory) {
        return ibanAccounts[ibanHash];
    }

    /**
     * @notice Get caller's IBAN hash
     */
    function getMyIBAN() external view returns (bytes32) {
        return addressToIBAN[msg.sender];
    }

    /**
     * @notice Format IBAN for display (view helper)
     * @param ibanHash The IBAN hash
     * @return A formatted string representation
     */
    function formatIBAN(bytes32 ibanHash) external view returns (string memory) {
        IBANAccount storage account = ibanAccounts[ibanHash];
        require(account.active, "IBAN not found");

        // Return format: "XX82 YYYY ZZZZ" where XX=country, YYYY=bank, ZZZZ=hash prefix
        bytes memory result = new bytes(14);
        result[0] = account.countryCode[0];
        result[1] = account.countryCode[1];
        result[2] = "8";
        result[3] = "2";
        result[4] = " ";
        result[5] = account.bankCode[0];
        result[6] = account.bankCode[1];
        result[7] = account.bankCode[2];
        result[8] = account.bankCode[3];
        result[9] = " ";
        // Add first 4 chars of hash (hex)
        bytes32 hash = ibanHash;
        result[10] = _toHexChar(uint8(hash[0]) >> 4);
        result[11] = _toHexChar(uint8(hash[0]) & 0x0f);
        result[12] = _toHexChar(uint8(hash[1]) >> 4);
        result[13] = _toHexChar(uint8(hash[1]) & 0x0f);

        return string(result);
    }

    function _toHexChar(uint8 value) internal pure returns (bytes1) {
        if (value < 10) {
            return bytes1(uint8(bytes1("0")) + value);
        }
        return bytes1(uint8(bytes1("A")) + value - 10);
    }

    // ============ RESERVE MANAGEMENT ============

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

