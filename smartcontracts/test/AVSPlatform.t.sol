// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/AVSPlatform.sol";

contract AVSPlatformTest is Test {
    AVSPlatform instance;
    address admin = address(1);
    address lister = address(2);
    address buyer = address(3);

    function setUp() public {
        AVSPlatform impl = new AVSPlatform();
        bytes memory init = abi.encodeCall(AVSPlatform.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = AVSPlatform(address(proxy));
    }

    // ── Initialization ──────────────────────────────────────────────────────

    function test_InitialTargetMarkets() public view {
        string[] memory markets = instance.getTargetMarkets();
        assertEq(markets.length, 15);
        assertEq(markets[0], "LK"); // Sri Lanka
        assertEq(markets[2], "VE"); // Venezuela
    }

    function test_ConstantsAreCorrect() public view {
        assertEq(instance.OBSIDIAN_SHARE(), 40);
        assertEq(instance.COUNTRY_SHARE(), 60);
    }

    // ── Country Management ──────────────────────────────────────────────────

    function test_RegisterCountry() public {
        vm.prank(admin);
        instance.registerCountry("VE", "Venezuela", 150_000);

        AVSPlatform.CountryProfile memory cp = instance.getCountryProfile("VE");
        assertEq(cp.name, "Venezuela");
        assertEq(cp.code, "VE");
        assertEq(cp.totalDebtUSD, 150_000);
        assertTrue(cp.active);
        assertEq(cp.revenueShare, 60);
    }

    function test_RegisterCountryOnlyOwner() public {
        vm.prank(lister);
        vm.expectRevert();
        instance.registerCountry("VE", "Venezuela", 150_000);
    }

    function test_RegisterCountryInvalidCodeReverts() public {
        vm.prank(admin);
        vm.expectRevert("Use ISO-2 code");
        instance.registerCountry("VEN", "Venezuela", 150_000); // 3 chars
    }

    function test_IssueAllocation() public {
        vm.prank(admin);
        instance.registerCountry("AR", "Argentina", 300_000);

        vm.prank(admin);
        instance.issueAllocation("AR", 200); // 2x multiplier

        AVSPlatform.CountryProfile memory cp = instance.getCountryProfile("AR");
        // allocation = 300_000 * 200 * 1e18 / 100 = 600_000_000 * 1e18
        assertEq(cp.allocationOICD, 300_000 * 200 * 1e18 / 100);
    }

    function test_IssueAllocationInvalidMultiplierReverts() public {
        vm.prank(admin);
        instance.registerCountry("AR", "Argentina", 300_000);

        vm.prank(admin);
        vm.expectRevert("Multiplier 1.5x-4.5x");
        instance.issueAllocation("AR", 100); // below min 150
    }

    // ── Lister Management ──────────────────────────────────────────────────

    function test_AuthorizeLister() public {
        vm.prank(admin);
        instance.authorizeLister(lister, true);
        assertTrue(instance.authorizedListers(lister));
    }

    function test_RevokeLister() public {
        vm.prank(admin);
        instance.authorizeLister(lister, true);
        vm.prank(admin);
        instance.authorizeLister(lister, false);
        assertFalse(instance.authorizedListers(lister));
    }

    // ── Asset Listing ──────────────────────────────────────────────────────

    function _setupCountryAndLister() internal {
        vm.prank(admin);
        instance.registerCountry("NG", "Nigeria", 100_000);
        vm.prank(admin);
        instance.authorizeLister(lister, true);
    }

    function test_ListAsset() public {
        _setupCountryAndLister();

        vm.prank(lister);
        uint256 assetId = instance.listAsset(
            "NG",
            AVSPlatform.AssetType.NaturalResource,
            AVSPlatform.InstrumentType.Spot,
            "Nigerian Crude Oil Reserve",
            "Proven oil reserves",
            500_000 * 1e18,
            1_000,
            500 * 1e18,
            100_000 * 1e18,
            200
        );

        assertEq(assetId, 1);
        assertEq(instance.totalAssetsListed(), 1);

        AVSPlatform.Asset memory a = instance.getAsset(1);
        assertEq(a.name, "Nigerian Crude Oil Reserve");
        assertEq(a.countryCode, "NG");
        assertEq(uint8(a.assetType), uint8(AVSPlatform.AssetType.NaturalResource));
        assertEq(uint8(a.status), uint8(AVSPlatform.AssetStatus.Active));
        assertEq(a.availableSupply, 1_000);
        assertEq(a.pricePerUnit, 500 * 1e18);
    }

    function test_ListAssetInvalidParamsReverts() public {
        _setupCountryAndLister();

        vm.prank(lister);
        vm.expectRevert("Invalid params");
        instance.listAsset(
            "NG",
            AVSPlatform.AssetType.Metal,
            AVSPlatform.InstrumentType.Spot,
            "Gold",
            "desc",
            0, // invalid zero value
            100,
            1e18,
            0,
            200
        );
    }

    function test_UnauthorizedListerReverts() public {
        _setupCountryAndLister();

        vm.prank(buyer); // not a lister
        vm.expectRevert("Not authorized lister");
        instance.listAsset(
            "NG",
            AVSPlatform.AssetType.Metal,
            AVSPlatform.InstrumentType.Spot,
            "Copper",
            "desc",
            100 * 1e18,
            50,
            2 * 1e18,
            0,
            200
        );
    }

    // ── Purchase Asset ──────────────────────────────────────────────────────

    function _listAsset() internal returns (uint256 assetId) {
        _setupCountryAndLister();
        vm.prank(lister);
        assetId = instance.listAsset(
            "NG",
            AVSPlatform.AssetType.Metal,
            AVSPlatform.InstrumentType.Spot,
            "Gold Reserve",
            "desc",
            1_000 * 1e18,
            100,
            10 * 1e18,
            0,
            200
        );
    }

    function test_PurchaseAsset() public {
        uint256 assetId = _listAsset();

        vm.prank(buyer);
        uint256 purchaseId = instance.purchaseAsset(assetId, 5);

        assertEq(purchaseId, 1);
        assertEq(instance.totalRevenue(), 50 * 1e18); // 5 * 10 OICD

        AVSPlatform.Asset memory a = instance.getAsset(assetId);
        assertEq(a.availableSupply, 95);
        assertEq(a.unitsSold, 5);

        AVSPlatform.Purchase memory p = instance.getPurchase(1);
        assertEq(p.buyer, buyer);
        assertEq(p.units, 5);
        assertTrue(p.settled);
    }

    function test_PurchaseAllUnitsMarksAsSold() public {
        uint256 assetId = _listAsset();

        vm.prank(buyer);
        instance.purchaseAsset(assetId, 100); // buy all

        AVSPlatform.Asset memory a = instance.getAsset(assetId);
        assertEq(uint8(a.status), uint8(AVSPlatform.AssetStatus.Sold));
        assertEq(a.availableSupply, 0);
    }

    function test_PurchaseExceedsSupplyReverts() public {
        uint256 assetId = _listAsset();

        vm.prank(buyer);
        vm.expectRevert("Invalid units");
        instance.purchaseAsset(assetId, 101); // over supply
    }

    function test_PurchaseInactiveAssetReverts() public {
        uint256 assetId = _listAsset();

        vm.prank(admin);
        instance.updateAssetStatus(assetId, AVSPlatform.AssetStatus.Paused);

        vm.prank(buyer);
        vm.expectRevert("Asset not active");
        instance.purchaseAsset(assetId, 5);
    }

    // ── Revenue Split & Views ───────────────────────────────────────────────

    function test_CountryRevenueSplit() public {
        _setupCountryAndLister();
        vm.prank(lister);
        uint256 assetId = instance.listAsset(
            "NG", AVSPlatform.AssetType.Metal, AVSPlatform.InstrumentType.Spot,
            "Gold", "desc", 1_000 * 1e18, 100, 10 * 1e18, 0, 200
        );
        vm.prank(buyer);
        instance.purchaseAsset(assetId, 100); // buys all, 1000 OICD total

        (uint256 countryShare, uint256 obsidianShare) = instance.getCountryRevenueSplit("NG");
        // totalValueSecuritized = 1000e18, 60% = 600e18, 40% = 400e18
        assertEq(countryShare, 600 * 1e18);
        assertEq(obsidianShare, 400 * 1e18);
    }

    function test_GetAssetsByCountry() public {
        uint256 id = _listAsset();
        uint256[] memory ids = instance.getAssetsByCountry("NG");
        assertEq(ids.length, 1);
        assertEq(ids[0], id);
    }

    function test_GetAssetsByType() public {
        _listAsset();
        uint256[] memory ids = instance.getAssetsByType(AVSPlatform.AssetType.Metal);
        assertEq(ids.length, 1);
    }

    function test_GetBuyerPurchases() public {
        uint256 assetId = _listAsset();
        vm.prank(buyer);
        instance.purchaseAsset(assetId, 3);
        vm.prank(buyer);
        instance.purchaseAsset(assetId, 2);

        uint256[] memory purchases = instance.getBuyerPurchases(buyer);
        assertEq(purchases.length, 2);
    }

    function test_UpdateAssetPrice() public {
        uint256 assetId = _listAsset();
        vm.prank(admin);
        instance.updateAssetPrice(assetId, 20 * 1e18);

        AVSPlatform.Asset memory a = instance.getAsset(assetId);
        assertEq(a.pricePerUnit, 20 * 1e18);
    }
}
