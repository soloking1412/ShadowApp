// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/OICDTreasury.sol";

/// @notice Minimal ERC20 used as a mock reserve asset in tests
contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Mock oracle that returns a configurable price
contract MockOracle {
    uint256 public price;
    uint256 public timestamp;

    constructor(uint256 _price) {
        price = _price;
        timestamp = block.timestamp;
    }

    function setPrice(uint256 _price) external {
        price = _price;
        timestamp = block.timestamp;
    }

    function setTimestamp(uint256 _timestamp) external {
        timestamp = _timestamp;
    }

    function getPrice() external view returns (uint256, uint256) {
        return (price, timestamp);
    }
}

contract OICDTreasuryTest is Test {
    OICDTreasury public treasury;
    MockERC20    public reserveAsset;
    MockOracle   public oracle;

    address public admin   = address(1);
    address public minter  = address(2);
    address public burner  = address(3);
    address public govRole = address(4);
    address public user    = address(5);
    address public trader  = address(6);

    // Matches OICDTreasury constants
    uint256 constant USD = 1;
    uint256 constant EUR = 2;
    uint256 constant MINT_LIMIT = 250_000_000_000 * 1e18;

    // ─────────────────────────────────────────────────────────────────────────
    // Setup
    // ─────────────────────────────────────────────────────────────────────────

    function setUp() public {
        // Deploy implementation then wrap in ERC1967Proxy
        OICDTreasury impl = new OICDTreasury();
        bytes memory initData = abi.encodeCall(
            OICDTreasury.initialize,
            ("https://metadata.oicd.io/{id}", admin, MINT_LIMIT)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        treasury = OICDTreasury(address(proxy));

        // Supporting contracts
        reserveAsset = new MockERC20("USD Coin", "USDC");
        oracle       = new MockOracle(1e18);

        // Grant roles from admin
        vm.startPrank(admin);
        treasury.grantRole(treasury.MINTER_ROLE(),       minter);
        treasury.grantRole(treasury.BURNER_ROLE(),       burner);
        treasury.grantRole(treasury.GOVERNMENT_ROLE(),   govRole);
        treasury.grantRole(treasury.ACTIVE_TRADER_ROLE(), trader);
        vm.stopPrank();

        // Fund admin with reserve asset tokens so deposits work
        reserveAsset.mint(admin, 1_000_000_000 * 1e18);

        // Pre-approve the treasury to pull reserve tokens
        vm.prank(admin);
        reserveAsset.approve(address(treasury), type(uint256).max);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Initialization
    // ─────────────────────────────────────────────────────────────────────────

    function test_initialize_rolesGranted() public view {
        assertTrue(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(treasury.hasRole(treasury.ADMIN_ROLE(),         admin));
        assertTrue(treasury.hasRole(treasury.MINTER_ROLE(),        admin));
        assertTrue(treasury.hasRole(treasury.BURNER_ROLE(),        admin));
        assertTrue(treasury.hasRole(treasury.UPGRADER_ROLE(),      admin));
    }

    function test_initialize_currenciesActive() public view {
        OICDTreasury.Currency memory usd = treasury.getCurrency(USD);
        assertEq(usd.symbol,        "OICD-USD");
        assertEq(usd.dailyMintLimit, MINT_LIMIT);
        assertTrue(usd.active);
        assertEq(usd.reserveRatio, 15000); // 150%
    }

    function test_initialize_reserveRatios() public view {
        assertEq(treasury.minReserveRatio(),       12000);
        assertEq(treasury.emergencyReserveRatio(), 10000);
        assertFalse(treasury.emergencyMode());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Reserve Deposit
    // ─────────────────────────────────────────────────────────────────────────

    function _depositReserve(uint256 amount, uint256 valuation) internal {
        vm.prank(admin);
        treasury.depositReserve(USD, address(reserveAsset), amount, valuation);
    }

    function test_depositReserve_updatesBalance() public {
        uint256 val = 500_000 * 1e18;
        _depositReserve(val, val);

        OICDTreasury.Currency memory usd = treasury.getCurrency(USD);
        assertEq(usd.reserveBalance, val);
        assertEq(treasury.totalReserveValue(), val);
    }

    function test_depositReserve_revertsOnZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert("Invalid amounts");
        treasury.depositReserve(USD, address(reserveAsset), 0, 0);
    }

    function test_depositReserve_revertsOnInactiveCurrency() public {
        vm.startPrank(admin);
        treasury.setCurrencyActive(USD, false);
        vm.expectRevert("Currency inactive");
        treasury.depositReserve(USD, address(reserveAsset), 100, 100);
        vm.stopPrank();
    }

    function test_depositReserve_onlyAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        treasury.depositReserve(USD, address(reserveAsset), 100, 100);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Minting
    // ─────────────────────────────────────────────────────────────────────────

    function _setupForMint(address recipient, uint256 mintAmount) internal {
        // Deposit enough reserves: need reserveRatio (150%) of mintAmount
        uint256 requiredReserve = (mintAmount * 15000) / 10000;
        reserveAsset.mint(admin, requiredReserve);

        vm.prank(admin);
        reserveAsset.approve(address(treasury), type(uint256).max);

        _depositReserve(requiredReserve, requiredReserve);

        // Give recipient KYC through a government-role update
        vm.prank(govRole);
        treasury.updateCompliance(recipient, true, false, "US");
    }

    function test_mint_increasesBalance() public {
        uint256 amount = 1_000 * 1e18;
        _setupForMint(user, amount);

        vm.prank(minter);
        treasury.mint(user, USD, amount, "");

        assertEq(treasury.balanceOf(user, USD), amount);
        assertEq(treasury.getCurrency(USD).totalSupply, amount);
    }

    function test_mint_emitsCurrencyMinted() public {
        uint256 amount = 1_000 * 1e18;
        _setupForMint(user, amount);

        vm.prank(minter);
        vm.expectEmit(true, true, false, true);
        emit OICDTreasury.CurrencyMinted(USD, user, amount, amount);
        treasury.mint(user, USD, amount, "");
    }

    function test_mint_revertsWithoutMinterRole() public {
        uint256 amount = 100 * 1e18;
        _setupForMint(user, amount);

        vm.prank(user);
        vm.expectRevert();
        treasury.mint(user, USD, amount, "");
    }

    function test_mint_revertsWithInsufficientReserves() public {
        // No reserves deposited — should revert
        vm.prank(govRole);
        treasury.updateCompliance(user, true, false, "US");

        vm.prank(minter);
        vm.expectRevert("Insufficient reserves");
        treasury.mint(user, USD, 1_000 * 1e18, "");
    }

    function test_mint_revertsOnZeroAmount() public {
        _setupForMint(user, 1_000 * 1e18);

        vm.prank(minter);
        vm.expectRevert("Invalid amount");
        treasury.mint(user, USD, 0, "");
    }

    function test_mint_revertsWhenKYCMissing() public {
        uint256 amount = 100 * 1e18;
        // Deposit reserves but skip KYC
        _depositReserve(amount * 2, amount * 2);

        vm.prank(minter);
        vm.expectRevert("KYC not verified");
        treasury.mint(user, USD, amount, "");
    }

    function test_mint_dailyLimitEnforced() public {
        // Set a tight daily limit
        vm.prank(admin);
        treasury.setDailyMintLimit(USD, 500 * 1e18);

        uint256 amount = 600 * 1e18;
        _setupForMint(user, amount);

        vm.prank(minter);
        vm.expectRevert("Exceeds daily mint limit");
        treasury.mint(user, USD, amount, "");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Burning
    // ─────────────────────────────────────────────────────────────────────────

    function test_burn_decreasesBalance() public {
        uint256 amount = 1_000 * 1e18;
        _setupForMint(user, amount);

        vm.prank(minter);
        treasury.mint(user, USD, amount, "");

        vm.prank(burner);
        treasury.burn(user, USD, amount);

        assertEq(treasury.balanceOf(user, USD), 0);
        assertEq(treasury.getCurrency(USD).totalSupply, 0);
    }

    function test_burn_emitsCurrencyBurned() public {
        uint256 amount = 500 * 1e18;
        _setupForMint(user, amount);

        vm.prank(minter);
        treasury.mint(user, USD, amount, "");

        vm.prank(burner);
        vm.expectEmit(true, true, false, true);
        emit OICDTreasury.CurrencyBurned(USD, user, amount, 0);
        treasury.burn(user, USD, amount);
    }

    function test_burn_revertsWithoutBurnerRole() public {
        uint256 amount = 100 * 1e18;
        _setupForMint(user, amount);

        vm.prank(minter);
        treasury.mint(user, USD, amount, "");

        vm.prank(user);
        vm.expectRevert();
        treasury.burn(user, USD, amount);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Compliance
    // ─────────────────────────────────────────────────────────────────────────

    function test_updateCompliance_storesData() public {
        vm.prank(govRole);
        treasury.updateCompliance(user, true, false, "UK");

        OICDTreasury.ComplianceCheck memory c = treasury.getComplianceStatus(user);
        assertTrue(c.kycVerified);
        assertFalse(c.sanctioned);
        assertEq(c.jurisdiction, "UK");
    }

    function test_updateCompliance_onlyGovernmentRole() public {
        vm.prank(user);
        vm.expectRevert();
        treasury.updateCompliance(user, true, false, "UK");
    }

    function test_updateCompliance_emitsEvent() public {
        vm.prank(govRole);
        vm.expectEmit(true, false, false, true);
        emit OICDTreasury.ComplianceUpdated(user, true, false);
        treasury.updateCompliance(user, true, false, "UK");
    }

    function test_mint_revertsForSanctionedAddress() public {
        uint256 amount = 100 * 1e18;
        _depositReserve(amount * 2, amount * 2);

        vm.prank(govRole);
        treasury.updateCompliance(user, true, true, "SY"); // sanctioned = true

        vm.prank(minter);
        vm.expectRevert("Address sanctioned");
        treasury.mint(user, USD, amount, "");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Frozen Balances
    // ─────────────────────────────────────────────────────────────────────────

    function test_freezeBalance_preventsTransfer() public {
        uint256 amount = 1_000 * 1e18;
        _setupForMint(user, amount);

        vm.prank(minter);
        treasury.mint(user, USD, amount, "");

        vm.prank(govRole);
        treasury.freezeBalance(user, USD, amount, 30 days, "AML Review");

        OICDTreasury.FrozenBalance memory fb = treasury.getFrozenBalance(user, USD);
        assertTrue(fb.active);
        assertEq(fb.amount, amount);
    }

    function test_unfreezeBalance_byGovernment() public {
        uint256 amount = 500 * 1e18;
        _setupForMint(user, amount);

        vm.prank(minter);
        treasury.mint(user, USD, amount, "");

        vm.prank(govRole);
        treasury.freezeBalance(user, USD, amount, 30 days, "Review");

        vm.prank(govRole);
        treasury.unfreezeBalance(user, USD);

        OICDTreasury.FrozenBalance memory fb = treasury.getFrozenBalance(user, USD);
        assertFalse(fb.active);
    }

    function test_autoUnfreeze_afterDuration() public {
        uint256 amount = 500 * 1e18;
        _setupForMint(user, amount);

        vm.prank(minter);
        treasury.mint(user, USD, amount, "");

        vm.prank(govRole);
        treasury.freezeBalance(user, USD, amount, 7 days, "Temporary");

        // Advance time past freeze duration
        vm.warp(block.timestamp + 8 days);

        treasury.autoUnfreeze(user, USD);

        OICDTreasury.FrozenBalance memory fb = treasury.getFrozenBalance(user, USD);
        assertFalse(fb.active);
    }

    function test_freezeBalance_revertsOnlyGovernment() public {
        vm.prank(user);
        vm.expectRevert();
        treasury.freezeBalance(user, USD, 100, 1 days, "Test");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Emergency Mode
    // ─────────────────────────────────────────────────────────────────────────

    function test_activateEmergencyMode() public {
        vm.prank(admin);
        treasury.activateEmergencyMode();

        assertTrue(treasury.emergencyMode());
        assertTrue(treasury.paused());
    }

    function test_deactivateEmergencyMode() public {
        vm.prank(admin);
        treasury.activateEmergencyMode();

        vm.prank(admin);
        treasury.deactivateEmergencyMode();

        assertFalse(treasury.emergencyMode());
        assertFalse(treasury.paused());
    }

    function test_activateEmergencyMode_revertsIfAlreadyActive() public {
        vm.prank(admin);
        treasury.activateEmergencyMode();

        vm.prank(admin);
        vm.expectRevert("Already in emergency mode");
        treasury.activateEmergencyMode();
    }

    function test_mint_revertsWhenPaused() public {
        uint256 amount = 100 * 1e18;
        _setupForMint(user, amount);

        vm.prank(admin);
        treasury.pause();

        vm.prank(minter);
        vm.expectRevert();
        treasury.mint(user, USD, amount, "");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. Admin Configuration Functions
    // ─────────────────────────────────────────────────────────────────────────

    function test_setDailyMintLimit() public {
        uint256 newLimit = 100_000 * 1e18;
        vm.prank(admin);
        treasury.setDailyMintLimit(USD, newLimit);

        assertEq(treasury.getCurrency(USD).dailyMintLimit, newLimit);
    }

    function test_setCurrencyActive_togglesCurrency() public {
        vm.prank(admin);
        treasury.setCurrencyActive(USD, false);

        assertFalse(treasury.getCurrency(USD).active);

        vm.prank(admin);
        treasury.setCurrencyActive(USD, true);

        assertTrue(treasury.getCurrency(USD).active);
    }

    function test_setUniversalAMM() public {
        address amm = address(0xDEAD);
        vm.prank(admin);
        treasury.setUniversalAMM(amm);
        assertEq(treasury.universalAMM(), amm);
    }

    function test_setUniversalAMM_revertsZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Invalid AMM address");
        treasury.setUniversalAMM(address(0));
    }

    function test_setForexTracker() public {
        address tracker = address(0xBEEF);
        vm.prank(admin);
        treasury.setForexTracker(tracker);
        assertEq(treasury.forexTracker(), tracker);
    }

    function test_setTradingLimits() public {
        vm.prank(admin);
        treasury.setTradingLimits(1_000 * 1e18, 10_000 * 1e18);

        assertEq(treasury.maxScalpAmount(),  1_000 * 1e18);
        assertEq(treasury.dailyScalpLimit(), 10_000 * 1e18);
    }

    function test_setTargetAllocation() public {
        vm.prank(admin);
        treasury.setTargetAllocation(USD, 3000); // 30%
        assertEq(treasury.targetAllocations(USD), 3000);
    }

    function test_setTargetAllocation_revertsAbove100Pct() public {
        vm.prank(admin);
        vm.expectRevert("Target exceeds 100%");
        treasury.setTargetAllocation(USD, 10001);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. Transaction History
    // ─────────────────────────────────────────────────────────────────────────

    function test_transactionRecordedOnMint() public {
        uint256 amount = 200 * 1e18;
        _setupForMint(user, amount);

        vm.prank(minter);
        treasury.mint(user, USD, amount, "");

        assertEq(treasury.getTotalTransactions(), 1);
        OICDTreasury.Transaction memory tx_ = treasury.getTransaction(0);
        assertEq(tx_.to,         user);
        assertEq(tx_.currencyId, USD);
        assertEq(tx_.amount,     amount);
    }

    function test_getTransactionHistory_range() public {
        uint256 amount = 100 * 1e18;
        // Setup reserves for two USD mints (need 150% of 2 * amount = 300e18)
        _setupForMint(user, amount * 3);

        vm.startPrank(minter);
        treasury.mint(user, USD, amount, "");
        vm.stopPrank();

        // Additional mint in next block to avoid duplicate txHash
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        // Second unique mint also uses USD — reserves already sufficient
        vm.prank(minter);
        treasury.mint(user, USD, amount, "");

        OICDTreasury.Transaction[] memory history = treasury.getTransactionHistory(0, 2);
        assertEq(history.length, 2);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. Reserve Ratio Enforcement
    // ─────────────────────────────────────────────────────────────────────────

    function test_setReserveRatio_requiresAboveMin() public {
        vm.prank(admin);
        vm.expectRevert("Below minimum");
        // minReserveRatio = 12000, so 11000 should revert
        treasury.setReserveRatio(USD, 11000);
    }

    function test_setMinReserveRatio_requiresAboveEmergency() public {
        vm.prank(admin);
        vm.expectRevert("Below emergency ratio");
        treasury.setMinReserveRatio(9000); // below emergencyReserveRatio (10000)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 11. Batch Operations
    // ─────────────────────────────────────────────────────────────────────────

    function test_mintBatch_multipleCurrencies() public {
        uint256 amount = 500 * 1e18;
        // Fund reserves for both USD and EUR
        _setupForMint(user, amount);
        // Also add EUR reserve
        uint256 required = (amount * 15000) / 10000;
        reserveAsset.mint(admin, required);
        vm.prank(admin);
        reserveAsset.approve(address(treasury), type(uint256).max);
        vm.prank(admin);
        treasury.depositReserve(EUR, address(reserveAsset), required, required);

        uint256[] memory ids    = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = USD; ids[1] = EUR;
        amounts[0] = amount; amounts[1] = amount;

        vm.prank(minter);
        treasury.mintBatch(user, ids, amounts, "");

        assertEq(treasury.balanceOf(user, USD), amount);
        assertEq(treasury.balanceOf(user, EUR), amount);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 12. UUPS Upgrade Authorization
    // ─────────────────────────────────────────────────────────────────────────

    function test_upgradeReverts_nonUpgrader() public {
        OICDTreasury impl2 = new OICDTreasury();
        vm.prank(user);
        vm.expectRevert();
        treasury.upgradeToAndCall(address(impl2), "");
    }
}
