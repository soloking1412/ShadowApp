// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/ObsidianCapital.sol";

contract ObsidianCapitalTest is Test {
    ObsidianCapital public fund;

    address public admin    = address(1);
    address public manager  = address(2);
    address public trader   = address(3);
    address public investor = address(4);
    address public other    = address(5);

    address public darkPool = address(0xD4);
    address public cex      = address(0xCE);

    // ─────────────────────────────────────────────────────────────────────────
    // Setup
    // ─────────────────────────────────────────────────────────────────────────

    function setUp() public {
        ObsidianCapital impl = new ObsidianCapital();
        bytes memory initData = abi.encodeCall(
            ObsidianCapital.initialize,
            (admin, darkPool, cex)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        fund = ObsidianCapital(payable(address(proxy)));

        // Grant additional roles
        vm.startPrank(admin);
        fund.grantRole(fund.FUND_MANAGER_ROLE(), manager);
        fund.grantRole(fund.TRADER_ROLE(),       trader);
        vm.stopPrank();

        // Give test accounts some ETH
        vm.deal(investor, 100 ether);
        vm.deal(manager,  10 ether);
        vm.deal(trader,   10 ether);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Initialization
    // ─────────────────────────────────────────────────────────────────────────

    function test_initialize_rolesGranted() public view {
        assertTrue(fund.hasRole(fund.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(fund.hasRole(fund.ADMIN_ROLE(),         admin));
        assertTrue(fund.hasRole(fund.FUND_MANAGER_ROLE(),  admin));
    }

    function test_initialize_darkPoolAndCEX() public view {
        assertEq(fund.darkPoolAddress(), darkPool);
        assertEq(fund.cexAddress(),      cex);
    }

    function test_initialize_fees() public view {
        assertEq(fund.managementFee(),  300);   // 3%
        assertEq(fund.performanceFee(), 3000);  // 30%
    }

    function test_initialize_navPerShare() public view {
        assertEq(fund.navPerShare(), 1e18);
    }

    function test_initialize_zeroAUM() public view {
        assertEq(fund.totalAUM(),    0);
        assertEq(fund.totalShares(), 0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Investing
    // ─────────────────────────────────────────────────────────────────────────

    function test_invest_basic() public {
        vm.prank(investor);
        fund.invest{value: 1 ether}();

        (
            address inv,
            uint256 amount,
            uint256 shares,
            ,
            ,
            ObsidianCapital.InvestmentStatus status,
        ) = fund.investments(investor);

        assertEq(inv,    investor);
        assertEq(amount, 1 ether);
        assertGt(shares, 0);
        assertEq(uint8(status), uint8(ObsidianCapital.InvestmentStatus.Active));
        assertEq(fund.totalAUM(), 1 ether);
    }

    function test_invest_emitsInvestmentMade() public {
        vm.prank(investor);
        vm.expectEmit(true, false, false, false);
        emit ObsidianCapital.InvestmentMade(investor, 1 ether, 1 ether, 0);
        fund.invest{value: 1 ether}();
    }

    function test_invest_revertsZeroValue() public {
        vm.prank(investor);
        vm.expectRevert("Invalid investment amount");
        fund.invest{value: 0}();
    }

    function test_invest_grantsInvestorRole() public {
        vm.prank(investor);
        fund.invest{value: 1 ether}();
        assertTrue(fund.hasRole(fund.INVESTOR_ROLE(), investor));
    }

    function test_invest_accumulatesForSameInvestor() public {
        vm.prank(investor);
        fund.invest{value: 1 ether}();

        vm.prank(investor);
        fund.invest{value: 2 ether}();

        (, uint256 amount, , , , , ) = fund.investments(investor);
        assertEq(amount, 3 ether);
        assertEq(fund.totalAUM(), 3 ether);
    }

    function test_invest_revertsWhenPaused() public {
        vm.prank(admin);
        fund.pause();

        vm.prank(investor);
        vm.expectRevert();
        fund.invest{value: 1 ether}();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Strategy Creation
    // ─────────────────────────────────────────────────────────────────────────

    function _setupAUM(uint256 amount) internal {
        vm.prank(investor);
        fund.invest{value: amount}();
    }

    function test_createStrategy_success() public {
        _setupAUM(10 ether);

        string[] memory corridors = new string[](2);
        corridors[0] = "USD-EUR";
        corridors[1] = "USD-JPY";

        vm.prank(manager);
        uint256 id = fund.createStrategy(
            ObsidianCapital.StrategyType.MacroPlay,
            "Macro Alpha",
            5 ether,
            corridors
        );

        assertEq(id, 1);

        (
            string memory name,
            uint256 allocated,
            uint256 currentValue,
            int256 pnl,
            uint256 volume
        ) = fund.getStrategyPerformance(1);

        assertEq(name,         "Macro Alpha");
        assertEq(allocated,    5 ether);
        assertEq(currentValue, 5 ether);
        assertEq(pnl,          0);
        assertEq(volume,       0);
    }

    function test_createStrategy_emitsEvent() public {
        _setupAUM(5 ether);
        string[] memory corridors = new string[](1);
        corridors[0] = "USD-CNY";

        vm.prank(manager);
        vm.expectEmit(true, false, false, false);
        emit ObsidianCapital.StrategyCreated(1, ObsidianCapital.StrategyType.Quant, "Quant", 1 ether);
        fund.createStrategy(ObsidianCapital.StrategyType.Quant, "Quant", 1 ether, corridors);
    }

    function test_createStrategy_revertsInsufficientAUM() public {
        // No AUM
        string[] memory corridors = new string[](1);
        corridors[0] = "USD-EUR";

        vm.prank(manager);
        vm.expectRevert("Insufficient AUM");
        fund.createStrategy(ObsidianCapital.StrategyType.MacroPlay, "Test", 1 ether, corridors);
    }

    function test_createStrategy_revertsNonManager() public {
        _setupAUM(5 ether);
        string[] memory corridors = new string[](1);
        corridors[0] = "USD-EUR";

        vm.prank(other);
        vm.expectRevert();
        fund.createStrategy(ObsidianCapital.StrategyType.MacroPlay, "Test", 1 ether, corridors);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Position Management
    // ─────────────────────────────────────────────────────────────────────────

    function _createMacroStrategy(uint256 capital) internal returns (uint256 strategyId) {
        _setupAUM(capital);
        string[] memory corridors = new string[](1);
        corridors[0] = "USD-EUR";

        vm.prank(manager);
        strategyId = fund.createStrategy(
            ObsidianCapital.StrategyType.MacroPlay,
            "Macro",
            capital,
            corridors
        );
    }

    function test_openPosition_success() public {
        uint256 stratId = _createMacroStrategy(10 ether);

        // trader already has TRADER_ROLE granted in setUp via vm.startPrank(admin)
        vm.prank(trader);
        uint256 posId = fund.openPosition(stratId, "EUR/USD", true, 1 ether, 1_000e18);

        assertEq(posId, 1);

        (
            uint256 positionId,
            uint256 strategyId,
            string memory asset,
            bool isLong,
            uint256 size,
            uint256 entryPrice,
            uint256 currentPrice,
            ,
            bool isOpen,
            int256 pnl
        ) = fund.positions(1);

        assertEq(positionId,    1);
        assertEq(strategyId,    stratId);
        assertEq(asset,         "EUR/USD");
        assertTrue(isLong);
        assertEq(size,          1 ether);
        assertEq(entryPrice,    1_000e18);
        assertEq(currentPrice,  1_000e18);
        assertTrue(isOpen);
        assertEq(pnl,           0);
    }

    function test_openPosition_emitsEvent() public {
        uint256 stratId = _createMacroStrategy(5 ether);

        vm.prank(trader);
        vm.expectEmit(true, true, false, true);
        emit ObsidianCapital.PositionOpened(1, stratId, "BTC/USD", false, 1 ether);
        fund.openPosition(stratId, "BTC/USD", false, 1 ether, 50_000e18);
    }

    function test_openPosition_revertsNonTrader() public {
        uint256 stratId = _createMacroStrategy(5 ether);

        vm.prank(other);
        vm.expectRevert();
        fund.openPosition(stratId, "EUR/USD", true, 1 ether, 1_000e18);
    }

    function test_openPosition_revertsExceedsAllocation() public {
        uint256 stratId = _createMacroStrategy(5 ether);

        vm.prank(trader);
        vm.expectRevert("Size exceeds allocation");
        fund.openPosition(stratId, "EUR/USD", true, 10 ether, 1_000e18);
    }

    function test_closePosition_longProfit() public {
        uint256 stratId = _createMacroStrategy(10 ether);

        vm.prank(trader);
        uint256 posId = fund.openPosition(stratId, "EUR/USD", true, 2 ether, 1_000e18);

        // Exit price higher than entry → profit for long
        vm.prank(trader);
        fund.closePosition(posId, 1_100e18);

        (, , , , , , , , bool isOpen, int256 pnl) = fund.positions(posId);
        assertFalse(isOpen);
        assertGt(pnl, 0);
    }

    function test_closePosition_shortProfit() public {
        uint256 stratId = _createMacroStrategy(10 ether);

        vm.prank(trader);
        uint256 posId = fund.openPosition(stratId, "EUR/USD", false, 2 ether, 1_000e18);

        // Exit price lower than entry → profit for short
        vm.prank(trader);
        fund.closePosition(posId, 900e18);

        (, , , , , , , , bool isOpen, int256 pnl) = fund.positions(posId);
        assertFalse(isOpen);
        assertGt(pnl, 0);
    }

    function test_closePosition_revertsAlreadyClosed() public {
        uint256 stratId = _createMacroStrategy(5 ether);

        vm.prank(trader);
        uint256 posId = fund.openPosition(stratId, "EUR/USD", true, 1 ether, 1_000e18);

        vm.prank(trader);
        fund.closePosition(posId, 1_100e18);

        vm.prank(trader);
        vm.expectRevert("Position not open");
        fund.closePosition(posId, 1_200e18);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. NAV Update
    // ─────────────────────────────────────────────────────────────────────────

    function test_updateNAV_afterProfit() public {
        uint256 stratId = _createMacroStrategy(10 ether);

        vm.prank(trader);
        uint256 posId = fund.openPosition(stratId, "EUR/USD", true, 5 ether, 1_000e18);

        vm.prank(trader);
        fund.closePosition(posId, 2_000e18); // 100% gain in price

        vm.prank(manager);
        fund.updateNAV();

        // AUM should have increased
        assertGt(fund.totalAUM(), 10 ether);
    }

    function test_updateNAV_emitsEvent() public {
        _setupAUM(1 ether);

        vm.prank(manager);
        vm.expectEmit(false, false, false, false);
        emit ObsidianCapital.NAVUpdated(0, 0);
        fund.updateNAV();
    }

    function test_updateNAV_revertsNonManager() public {
        vm.prank(other);
        vm.expectRevert();
        fund.updateNAV();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Withdrawal
    // ─────────────────────────────────────────────────────────────────────────

    function test_withdraw_afterLockup() public {
        vm.prank(investor);
        fund.invest{value: 5 ether}();

        vm.warp(block.timestamp + 91 days); // past 90-day lockup

        uint256 balBefore = investor.balance;
        vm.prank(investor);
        fund.withdraw();

        (, , , , , ObsidianCapital.InvestmentStatus status, ) = fund.investments(investor);
        assertEq(uint8(status), uint8(ObsidianCapital.InvestmentStatus.Withdrawn));
        // Investor should receive ETH minus management fee (3%)
        assertGt(investor.balance, balBefore);
    }

    function test_withdraw_revertsBeforeLockup() public {
        vm.prank(investor);
        fund.invest{value: 1 ether}();

        vm.prank(investor);
        vm.expectRevert("Lockup period not ended");
        fund.withdraw();
    }

    function test_withdraw_revertsIfAlreadyWithdrawn() public {
        vm.prank(investor);
        fund.invest{value: 1 ether}();

        vm.warp(block.timestamp + 91 days);

        vm.prank(investor);
        fund.withdraw();

        vm.prank(investor);
        vm.expectRevert("Investment not active");
        fund.withdraw();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Fund Performance View
    // ─────────────────────────────────────────────────────────────────────────

    function test_getFundPerformance_initial() public view {
        (uint256 aum, uint256 nav, uint256 investorCount, uint256 activeStrategies) =
            fund.getFundPerformance();

        assertEq(aum,             0);
        assertEq(nav,             1e18);
        assertEq(investorCount,   0);
        assertEq(activeStrategies, 0);
    }

    function test_getFundPerformance_afterInvestAndStrategy() public {
        _setupAUM(10 ether);

        string[] memory corridors = new string[](1);
        corridors[0] = "USD-EUR";
        vm.prank(manager);
        fund.createStrategy(ObsidianCapital.StrategyType.MacroPlay, "Macro", 5 ether, corridors);

        (uint256 aum, , uint256 invCount, uint256 active) = fund.getFundPerformance();
        assertEq(aum,     10 ether);
        assertEq(invCount, 1);
        assertEq(active,   1);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. Pause / Unpause
    // ─────────────────────────────────────────────────────────────────────────

    function test_pause_onlyAdmin() public {
        vm.prank(other);
        vm.expectRevert();
        fund.pause();
    }

    function test_pauseAndUnpause() public {
        vm.prank(admin);
        fund.pause();
        assertTrue(fund.paused());

        vm.prank(admin);
        fund.unpause();
        assertFalse(fund.paused());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. UUPS Upgrade Authorization
    // ─────────────────────────────────────────────────────────────────────────

    function test_upgradeReverts_nonAdmin() public {
        ObsidianCapital impl2 = new ObsidianCapital();
        vm.prank(other);
        vm.expectRevert();
        fund.upgradeToAndCall(address(impl2), "");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. Market Corridor Allocations
    // ─────────────────────────────────────────────────────────────────────────

    function test_marketCorridorAllocations_setOnStrategyCreate() public {
        _setupAUM(10 ether);

        string[] memory corridors = new string[](2);
        corridors[0] = "USD-EUR";
        corridors[1] = "EUR-GBP";

        vm.prank(manager);
        fund.createStrategy(
            ObsidianCapital.StrategyType.CurrencyArbitrage,
            "FX Arb",
            4 ether,
            corridors
        );

        // Each corridor gets half the capital (4 ether / 2 corridors = 2 ether each)
        assertEq(fund.marketCorridorAllocations("USD-EUR"), 2 ether);
        assertEq(fund.marketCorridorAllocations("EUR-GBP"), 2 ether);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 11. Multiple Strategies
    // ─────────────────────────────────────────────────────────────────────────

    function test_multipleStrategies_incrementCounter() public {
        _setupAUM(20 ether);

        string[] memory corridors = new string[](1);
        corridors[0] = "USD-EUR";

        vm.startPrank(manager);
        fund.createStrategy(ObsidianCapital.StrategyType.MacroPlay, "Macro",   5 ether, corridors);
        fund.createStrategy(ObsidianCapital.StrategyType.Quant,     "Quant",   3 ether, corridors);
        fund.createStrategy(ObsidianCapital.StrategyType.LongShort, "L/S",     2 ether, corridors);
        vm.stopPrank();

        assertEq(fund.strategyCounter(), 3);
    }
}
