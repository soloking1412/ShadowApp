// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/LiquidityAsAService.sol";

contract LiquidityAsAServiceTest is Test {
    LiquidityAsAService instance;
    address admin = address(1);
    address provider1 = address(2);
    address provider2 = address(3);
    address marketMaker = address(4);
    address lpProvider = address(5);

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant LIQUIDITY_PROVIDER_ROLE = keccak256("LIQUIDITY_PROVIDER_ROLE");
    bytes32 public constant MARKET_MAKER_ROLE = keccak256("MARKET_MAKER_ROLE");

    function setUp() public {
        LiquidityAsAService impl = new LiquidityAsAService();
        bytes memory init = abi.encodeCall(LiquidityAsAService.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = LiquidityAsAService(payable(address(proxy)));

        // Grant roles
        vm.prank(admin);
        instance.grantRole(MARKET_MAKER_ROLE, marketMaker);
        vm.prank(admin);
        instance.grantRole(LIQUIDITY_PROVIDER_ROLE, lpProvider);

        // Fund test accounts
        vm.deal(provider1, 1_000_000 ether);
        vm.deal(provider2, 1_000_000 ether);
        vm.deal(admin, 1_000_000 ether);
    }

    // ── Initialization ──────────────────────────────────────────────────────

    function test_AdminHasAllRoles() public view {
        assertTrue(instance.hasRole(ADMIN_ROLE, admin));
        assertTrue(instance.hasRole(LIQUIDITY_PROVIDER_ROLE, admin));
        assertTrue(instance.hasRole(MARKET_MAKER_ROLE, admin));
    }

    function test_Constants() public view {
        assertEq(instance.BASIS_POINTS(), 10_000);
        assertEq(instance.LOCKUP_PERIOD(), 30 days);
    }

    // ── Pool Creation ───────────────────────────────────────────────────────

    function _createFXPool() internal returns (uint256 poolId) {
        string[] memory pairs = new string[](2);
        pairs[0] = "USD/EUR";
        pairs[1] = "OICD/OTD";

        vm.prank(admin);
        poolId = instance.createPool(
            LiquidityAsAService.PoolType.FX,
            "FX Liquidity Pool",
            pairs,
            50 // 0.5% spread
        );
    }

    function test_CreatePool() public {
        uint256 poolId = _createFXPool();

        assertEq(poolId, 1);
        assertEq(instance.poolCounter(), 1);

        (
            LiquidityAsAService.PoolType poolType,
            string memory name,
            uint256 totalLiquidity,
            uint256 utilizationRate,
            uint256 spreadBps,
            LiquidityAsAService.PoolStatus status,
            uint256 cumulativeVolume
        ) = instance.getPool(poolId);

        assertEq(uint8(poolType), uint8(LiquidityAsAService.PoolType.FX));
        assertEq(name, "FX Liquidity Pool");
        assertEq(totalLiquidity, 0);
        assertEq(utilizationRate, 0);
        assertEq(spreadBps, 50);
        assertEq(uint8(status), uint8(LiquidityAsAService.PoolStatus.Active));
        assertEq(cumulativeVolume, 0);
    }

    function test_CreatePoolNonAdminReverts() public {
        string[] memory pairs = new string[](1);
        pairs[0] = "A/B";

        vm.prank(provider1);
        vm.expectRevert();
        instance.createPool(LiquidityAsAService.PoolType.FX, "Pool", pairs, 10);
    }

    function test_CreatePoolNoAssetPairsReverts() public {
        string[] memory pairs = new string[](0);

        vm.prank(admin);
        vm.expectRevert("No asset pairs");
        instance.createPool(LiquidityAsAService.PoolType.Securities, "Pool", pairs, 10);
    }

    function test_CreatePoolInvalidSpreadReverts() public {
        string[] memory pairs = new string[](1);
        pairs[0] = "A/B";

        vm.prank(admin);
        vm.expectRevert("Invalid spread");
        instance.createPool(LiquidityAsAService.PoolType.FX, "Pool", pairs, 1001); // over 1000
    }

    // ── Provide Liquidity ───────────────────────────────────────────────────

    function test_ProvideLiquidity() public {
        uint256 poolId = _createFXPool();

        vm.prank(provider1);
        uint256 positionId = instance.provideLiquidity{value: 100 ether}(poolId);

        assertEq(positionId, 1);
        assertEq(instance.positionCounter(), 1);
        assertEq(instance.totalLiquidityProvided(), 100 ether);

        (
            ,
            uint256 _posPoolId,
            address _provider,
            uint256 _amount,
            ,
            ,
            uint256 _lockupEnd,
            ,
            bool _active
        ) = instance.positions(positionId);
        assertEq(_provider, provider1);
        assertEq(_amount, 100 ether);
        assertEq(_posPoolId, poolId);
        assertTrue(_active);
        assertGt(_lockupEnd, block.timestamp);
    }

    function test_ProvideLiquidityZeroReverts() public {
        uint256 poolId = _createFXPool();

        vm.prank(provider1);
        vm.expectRevert("Invalid amount");
        instance.provideLiquidity{value: 0}(poolId);
    }

    function test_MultipleProviders() public {
        uint256 poolId = _createFXPool();

        vm.prank(provider1);
        instance.provideLiquidity{value: 100 ether}(poolId);

        vm.prank(provider2);
        instance.provideLiquidity{value: 200 ether}(poolId);

        (, , uint256 totalLiquidity, , , , ) = instance.getPool(poolId);
        assertEq(totalLiquidity, 300 ether);

        address[] memory providers = instance.getPoolProviders(poolId);
        assertEq(providers.length, 2);
    }

    // ── Withdraw Liquidity ──────────────────────────────────────────────────

    function test_WithdrawAfterLockup() public {
        uint256 poolId = _createFXPool();

        vm.prank(provider1);
        uint256 positionId = instance.provideLiquidity{value: 100 ether}(poolId);

        // Need contract to have enough ETH for withdrawal.
        // When pool.totalLiquidity=0 at deposit, shares = msg.value (100 ether, not normalized).
        // withdrawAmount = (shares * pool.totalLiquidity) / 1e18
        //                = (100e18 * 100e18) / 1e18 = 10_000 ether.
        vm.deal(address(instance), 100_000 ether);

        // Fast-forward past lockup
        vm.warp(block.timestamp + 31 days);

        uint256 balanceBefore = provider1.balance;
        vm.prank(provider1);
        instance.withdrawLiquidity(positionId);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            bool _posActive
        ) = instance.positions(positionId);
        assertFalse(_posActive);
        assertGt(provider1.balance, balanceBefore);
    }

    function test_WithdrawBeforeLockupReverts() public {
        uint256 poolId = _createFXPool();

        vm.prank(provider1);
        uint256 positionId = instance.provideLiquidity{value: 100 ether}(poolId);

        vm.prank(provider1);
        vm.expectRevert("Lockup period not ended");
        instance.withdrawLiquidity(positionId);
    }

    function test_WithdrawNonOwnerReverts() public {
        uint256 poolId = _createFXPool();

        vm.prank(provider1);
        uint256 positionId = instance.provideLiquidity{value: 100 ether}(poolId);

        vm.warp(block.timestamp + 31 days);

        vm.prank(provider2);
        vm.expectRevert("Not position owner");
        instance.withdrawLiquidity(positionId);
    }

    // ── Market Making ───────────────────────────────────────────────────────

    function test_PlaceMarketOrder() public {
        uint256 poolId = _createFXPool();
        vm.prank(admin);
        instance.provideLiquidity{value: 1000 ether}(poolId);

        vm.prank(marketMaker);
        uint256 orderId = instance.placeMarketOrder(poolId, "USD/EUR", 100_000, 50);

        assertEq(orderId, 1);

        (, uint256 _orderPoolId, string memory _assetPair, uint256 _bidPrice, uint256 _askPrice, , , , bool _orderActive) = instance.orders(orderId);
        assertEq(_orderPoolId, poolId);
        assertEq(_assetPair, "USD/EUR");
        assertTrue(_orderActive);
        // bid = 100_000 - (100_000 * 50 / 20_000) = 100_000 - 250 = 99_750
        // ask = 100_000 + 250 = 100_250
        assertEq(_bidPrice, 99_750);
        assertEq(_askPrice, 100_250);
    }

    function test_PlaceMarketOrderNonMarketMakerReverts() public {
        uint256 poolId = _createFXPool();

        vm.prank(provider1);
        vm.expectRevert();
        instance.placeMarketOrder(poolId, "USD/EUR", 100_000, 50);
    }

    // ── Cross-Border Flow ───────────────────────────────────────────────────

    function test_ExecuteCrossBorderFlow() public {
        string[] memory pairs = new string[](1);
        pairs[0] = "USD/EUR";
        vm.prank(admin);
        uint256 poolId = instance.createPool(
            LiquidityAsAService.PoolType.CrossBorder,
            "Cross-Border Pool",
            pairs,
            20
        );

        vm.prank(lpProvider);
        uint256 flowId = instance.executeCrossBorderFlow(
            poolId,
            "USD",
            "EUR",
            "US",
            "DE",
            1_000_000,
            108 // exchange rate
        );

        assertEq(flowId, 1);
        assertEq(instance.totalVolumeTraded(), 1_000_000);

        (, , string memory _fromCurrency, string memory _toCurrency, , , , , uint256 _flowFee, , bool _flowCompleted) = instance.flows(flowId);
        assertEq(_fromCurrency, "USD");
        assertEq(_toCurrency, "EUR");
        assertTrue(_flowCompleted);
        assertGt(_flowFee, 0);
    }

    function test_CrossBorderFlowWrongPoolTypeReverts() public {
        // FX pool is OK, Securities pool is not
        string[] memory pairs = new string[](1);
        pairs[0] = "STOCK/USD";
        vm.prank(admin);
        uint256 poolId = instance.createPool(
            LiquidityAsAService.PoolType.Securities,
            "Securities Pool",
            pairs,
            30
        );

        vm.prank(lpProvider);
        vm.expectRevert("Wrong pool type");
        instance.executeCrossBorderFlow(poolId, "USD", "EUR", "US", "DE", 1_000, 1);
    }

    // ── Reward Distribution ─────────────────────────────────────────────────

    function test_DistributeRewards() public {
        string[] memory pairs = new string[](1);
        pairs[0] = "USD/EUR";
        vm.prank(admin);
        uint256 poolId = instance.createPool(LiquidityAsAService.PoolType.CrossBorder, "CB Pool", pairs, 50);

        vm.prank(admin);
        instance.provideLiquidity{value: 1000 ether}(poolId);

        // Generate fees via cross-border flow
        vm.prank(admin);
        instance.executeCrossBorderFlow(poolId, "USD", "EUR", "US", "DE", 10_000_000, 1);

        (, , , , uint256 spreadBps, , ) = instance.getPool(poolId);
        uint256 expectedFee = (10_000_000 * spreadBps) / 10_000;

        vm.prank(admin);
        instance.distributeRewards(poolId);

        assertEq(instance.totalFeesCollected(), expectedFee);
    }

    function test_DistributeRewardsNoFeesReverts() public {
        uint256 poolId = _createFXPool();

        vm.prank(admin);
        vm.expectRevert("No fees to distribute");
        instance.distributeRewards(poolId);
    }

    // ── Utilization Update ──────────────────────────────────────────────────

    function test_UpdateUtilization() public {
        uint256 poolId = _createFXPool();

        vm.prank(marketMaker);
        instance.updateUtilization(poolId, 7500); // 75%

        (, , , uint256 utilizationRate, , , ) = instance.getPool(poolId);
        assertEq(utilizationRate, 7500);
    }

    function test_UpdateUtilizationAbove100PctReverts() public {
        uint256 poolId = _createFXPool();

        vm.prank(marketMaker);
        vm.expectRevert("Invalid utilization");
        instance.updateUtilization(poolId, 10_001); // over 100%
    }

    // ── Pause ───────────────────────────────────────────────────────────────

    function test_PausePreventsLiquidityProvision() public {
        uint256 poolId = _createFXPool();

        vm.prank(admin);
        instance.pause();

        vm.prank(provider1);
        vm.expectRevert();
        instance.provideLiquidity{value: 100 ether}(poolId);
    }

    // ── Provider Pools ──────────────────────────────────────────────────────

    function test_GetProviderPools() public {
        uint256 pool1 = _createFXPool();

        string[] memory pairs = new string[](1);
        pairs[0] = "B/C";
        vm.prank(admin);
        uint256 pool2 = instance.createPool(LiquidityAsAService.PoolType.Commodities, "Comm", pairs, 20);

        vm.prank(provider1);
        instance.provideLiquidity{value: 50 ether}(pool1);
        vm.prank(provider1);
        instance.provideLiquidity{value: 50 ether}(pool2);

        uint256[] memory pPools = instance.getProviderPools(provider1);
        assertEq(pPools.length, 2);
        assertEq(pPools[0], pool1);
        assertEq(pPools[1], pool2);
    }
}
