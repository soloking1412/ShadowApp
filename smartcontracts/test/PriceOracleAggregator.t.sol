// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/PriceOracleAggregator.sol";

/// @dev Mock Chainlink aggregator that returns configurable prices
contract MockAggregator {
    int256 public price;
    uint256 public updatedAt;
    uint8 public dec;

    constructor(int256 _price, uint8 _dec) {
        price = _price;
        dec = _dec;
        updatedAt = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAtTs,
            uint80 answeredInRound
        )
    {
        return (1, price, block.timestamp, updatedAt, 1);
    }

    function decimals() external view returns (uint8) {
        return dec;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }

    function setUpdatedAt(uint256 _ts) external {
        updatedAt = _ts;
    }
}

contract PriceOracleAggregatorTest is Test {
    PriceOracleAggregator instance;
    address admin = address(1);
    address oracleManager = address(2);
    address asset1 = address(100);
    address asset2 = address(101);

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");

    MockAggregator primaryFeed;
    MockAggregator backupFeed;

    function setUp() public {
        PriceOracleAggregator impl = new PriceOracleAggregator();
        bytes memory init = abi.encodeCall(PriceOracleAggregator.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = PriceOracleAggregator(address(proxy));

        vm.prank(admin);
        instance.grantRole(ORACLE_MANAGER_ROLE, oracleManager);

        // Deploy mock feeds with 8 decimals (standard Chainlink)
        primaryFeed = new MockAggregator(200_000_000_00, 8); // $2,000.00 with 8 dec
        backupFeed  = new MockAggregator(200_100_000_00, 8); // $2,001.00 with 8 dec
    }

    // ── Initialization ──────────────────────────────────────────────────────

    function test_AdminHasRoles() public view {
        assertTrue(instance.hasRole(ADMIN_ROLE, admin));
        assertTrue(instance.hasRole(ORACLE_MANAGER_ROLE, admin));
    }

    function test_Constants() public view {
        assertEq(instance.MAX_PRICE_DEVIATION(), 500); // 5%
        assertEq(instance.STALENESS_THRESHOLD(), 3600); // 1 hour
    }

    // ── Register Price Feed ────────────────────────────────────────────────

    function test_RegisterPriceFeed() public {
        vm.prank(oracleManager);
        instance.registerPriceFeed(asset1, address(primaryFeed), 3600);

        (address _chainlinkFeed, , , uint256 _heartbeat, uint8 _decimals, bool _feedActive) = instance.assetFeeds(asset1);
        assertEq(_chainlinkFeed, address(primaryFeed));
        assertEq(_heartbeat, 3600);
        assertTrue(_feedActive);
        assertEq(_decimals, 8);
    }

    function test_RegisterFeedNonManagerReverts() public {
        vm.prank(address(99));
        vm.expectRevert();
        instance.registerPriceFeed(asset1, address(primaryFeed), 3600);
    }

    function test_RegisterFeedInvalidAssetReverts() public {
        vm.prank(oracleManager);
        vm.expectRevert("Invalid asset");
        instance.registerPriceFeed(address(0), address(primaryFeed), 3600);
    }

    function test_RegisterFeedInvalidFeedReverts() public {
        vm.prank(oracleManager);
        vm.expectRevert("Invalid feed");
        instance.registerPriceFeed(asset1, address(0), 3600);
    }

    function test_RegisteredAssetsTracked() public {
        vm.prank(oracleManager);
        instance.registerPriceFeed(asset1, address(primaryFeed), 3600);
        vm.prank(oracleManager);
        instance.registerPriceFeed(asset2, address(backupFeed), 3600);

        address[] memory assets = instance.getRegisteredAssets();
        assertEq(assets.length, 2);
        assertEq(assets[0], asset1);
        assertEq(assets[1], asset2);
    }

    // ── Add Backup Feed ─────────────────────────────────────────────────────

    function test_AddBackupFeed() public {
        vm.prank(oracleManager);
        instance.registerPriceFeed(asset1, address(primaryFeed), 3600);

        vm.prank(oracleManager);
        instance.addBackupFeed(asset1, address(backupFeed));

        // backupFeeds is a mapping(address => address[]), index 0 gives first element
        address firstBackup = instance.backupFeeds(asset1, 0);
        assertEq(firstBackup, address(backupFeed));
    }

    function test_AddBackupFeedUnregisteredReverts() public {
        vm.prank(oracleManager);
        vm.expectRevert("Asset not registered");
        instance.addBackupFeed(asset1, address(backupFeed));
    }

    // ── Get Latest Price ────────────────────────────────────────────────────

    function test_GetLatestPrice() public {
        vm.prank(oracleManager);
        instance.registerPriceFeed(asset1, address(primaryFeed), 3600);

        (uint256 price, uint256 timestamp) = instance.getLatestPrice(asset1);
        // 200_000_000_00 with 8 dec → normalized to 18 dec = 200_000_000_00 * 10^10 = 2000 * 1e18
        assertEq(price, 200_000_000_00 * 10**10);
        assertGt(timestamp, 0);
    }

    function test_GetLatestPriceInactiveFeedReverts() public {
        vm.prank(address(99));
        vm.expectRevert("Feed not active");
        instance.getLatestPrice(asset1);
    }

    function test_GetLatestPriceStalePriceReverts() public {
        vm.prank(oracleManager);
        instance.registerPriceFeed(asset1, address(primaryFeed), 3600);

        // Advance time so block.timestamp > 3700 (Foundry default is 1, causing underflow)
        vm.warp(10_000);

        // Make price stale: set updatedAt to more than 1 hour ago
        primaryFeed.setUpdatedAt(block.timestamp - 3700);

        vm.expectRevert("Stale price");
        instance.getLatestPrice(asset1);
    }

    function test_GetLatestPriceNegativePriceReverts() public {
        MockAggregator negativeFeed = new MockAggregator(-1, 8);

        vm.prank(oracleManager);
        instance.registerPriceFeed(asset1, address(negativeFeed), 3600);

        vm.expectRevert("Invalid price");
        instance.getLatestPrice(asset1);
    }

    // ── Price Staleness ─────────────────────────────────────────────────────

    function test_IsPriceStaleWhenFresh() public {
        vm.prank(oracleManager);
        instance.registerPriceFeed(asset1, address(primaryFeed), 3600);

        assertFalse(instance.isPriceStale(asset1));
    }

    function test_IsPriceStaleWhenOld() public {
        vm.prank(oracleManager);
        instance.registerPriceFeed(asset1, address(primaryFeed), 3600);

        // Advance time so block.timestamp > 3700 (Foundry default is 1, causing underflow)
        vm.warp(10_000);

        // Set updatedAt to more than 1 hour ago so price is considered stale
        primaryFeed.setUpdatedAt(block.timestamp - 3700);

        assertTrue(instance.isPriceStale(asset1));
    }

    function test_IsPriceStaleForUnregisteredAsset() public view {
        assertTrue(instance.isPriceStale(asset1)); // not registered → stale
    }

    // ── Price Deviation ─────────────────────────────────────────────────────

    function test_CheckPriceDeviationWithinRange() public {
        vm.prank(oracleManager);
        instance.registerPriceFeed(asset1, address(primaryFeed), 3600);

        uint256 currentPrice = 200_000_000_00 * 10**10; // 2000e18
        uint256 targetPrice  = 200_000_000_00 * 10**10; // same

        (bool withinRange, uint256 deviation) = instance.checkPriceDeviation(asset1, targetPrice);
        assertTrue(withinRange);
        assertEq(deviation, 0);
    }

    function test_CheckPriceDeviationOutOfRange() public {
        vm.prank(oracleManager);
        instance.registerPriceFeed(asset1, address(primaryFeed), 3600);

        uint256 currentPrice = 200_000_000_00 * 10**10; // 2000e18
        uint256 targetPrice  = currentPrice * 90 / 100;  // 10% lower (exceeds 5% threshold)

        (bool withinRange, uint256 deviation) = instance.checkPriceDeviation(asset1, targetPrice);
        assertFalse(withinRange);
        assertGt(deviation, 500); // > 5%
    }

    // ── Aggregated Price ────────────────────────────────────────────────────

    function test_GetAggregatedPriceNoBackup() public {
        vm.prank(oracleManager);
        instance.registerPriceFeed(asset1, address(primaryFeed), 3600);

        (uint256 price, uint256 confidence) = instance.getAggregatedPrice(asset1);
        assertGt(price, 0);
        assertEq(confidence, 100); // 100% when no backup feeds
    }

    function test_GetAggregatedPriceWithBackup() public {
        vm.prank(oracleManager);
        instance.registerPriceFeed(asset1, address(primaryFeed), 3600);
        vm.prank(oracleManager);
        instance.addBackupFeed(asset1, address(backupFeed));

        (uint256 price, uint256 confidence) = instance.getAggregatedPrice(asset1);
        assertGt(price, 0);
        assertEq(confidence, 100); // 2 valid prices, 2 total → 100%
    }

    // ── Pause / Unpause ─────────────────────────────────────────────────────

    function test_PauseByAdmin() public {
        vm.prank(admin);
        instance.pause();
        assertTrue(instance.paused());
    }

    function test_UnpauseByAdmin() public {
        vm.prank(admin);
        instance.pause();
        vm.prank(admin);
        instance.unpause();
        assertFalse(instance.paused());
    }

    function test_PauseNonAdminReverts() public {
        vm.prank(address(99));
        vm.expectRevert();
        instance.pause();
    }
}
