// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/DigitalTradeExchange.sol";

contract DigitalTradeExchangeTest is Test {
    DigitalTradeExchange instance;
    address admin = address(1);
    address company1Reg = address(2);
    address company2Reg = address(3);
    address buyer = address(4);
    address seller = address(5);
    address unauthorized = address(6);

    function setUp() public {
        DigitalTradeExchange impl = new DigitalTradeExchange();
        bytes memory init = abi.encodeCall(DigitalTradeExchange.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = DigitalTradeExchange(address(proxy));
    }

    // ── Initialization ──────────────────────────────────────────────────────

    function test_InitialCenters() public view {
        DigitalTradeExchange.ExchangeCenter[5] memory centers = instance.getAllCenters();

        assertEq(centers[0].name, "Alpha Exchange");
        assertEq(centers[0].country, "Puerto Rico");
        assertTrue(centers[0].active);

        assertEq(centers[1].name, "Bravo Exchange");
        assertEq(centers[1].country, "Colombia");

        assertEq(centers[2].name, "Charlie Exchange");
        assertEq(centers[2].country, "Ghana");

        assertEq(centers[3].name, "Delta Exchange");
        assertEq(centers[3].country, "Sri Lanka");

        assertEq(centers[4].name, "Echo Exchange");
        assertEq(centers[4].country, "Indonesia");
    }

    function test_InitialFees() public view {
        assertEq(instance.listingFeeOICD(), 10_000 * 1e18);
        assertEq(instance.tradingFeesBps(), 9);
    }

    // ── Company Listing ─────────────────────────────────────────────────────

    function _listCompany(address reg, string memory ticker, DigitalTradeExchange.Center center)
        internal
        returns (uint256 companyId)
    {
        vm.prank(reg);
        companyId = instance.listCompany(
            "Acme Corporation",
            ticker,
            "Technology",
            center,
            1_000_000_000,  // 1 billion shares
            10 * 1e18       // $10 OICD per share
        );
    }

    function test_ListCompany() public {
        uint256 id = _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);

        assertEq(id, 0); // 0-indexed array
        assertEq(instance.companyCount(), 1);

        DigitalTradeExchange.Company memory c = instance.getCompany(0);
        assertEq(c.name, "Acme Corporation");
        assertEq(c.ticker, "ACME");
        assertEq(c.sector, "Technology");
        assertEq(uint8(c.center), uint8(DigitalTradeExchange.Center.Alpha));
        assertEq(c.registrant, company1Reg);
        assertEq(c.sharesTotal, 1_000_000_000);
        assertEq(c.priceOICD, 10 * 1e18);
        assertTrue(c.listed);
        assertEq(c.marketCap, (1_000_000_000 * 10 * 1e18) / 1e18);

        // Registrant auto-authorized
        assertTrue(instance.authorizedTraders(0, company1Reg));
    }

    function test_ListCompanyDuplicateTickerReverts() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);

        vm.prank(company2Reg);
        vm.expectRevert("DTX: ticker already listed");
        instance.listCompany("Another Co", "ACME", "Finance", DigitalTradeExchange.Center.Bravo, 1000, 1e18);
    }

    function test_ListCompanyInvalidTickerLengthReverts() public {
        vm.prank(company1Reg);
        vm.expectRevert("DTX: invalid ticker length");
        instance.listCompany("Corp", "A", "Sector", DigitalTradeExchange.Center.Alpha, 1000, 1e18); // too short
    }

    function test_ListCompanyZeroSharesReverts() public {
        vm.prank(company1Reg);
        vm.expectRevert("DTX: zero shares");
        instance.listCompany("Corp", "CORP", "Sector", DigitalTradeExchange.Center.Alpha, 0, 1e18);
    }

    function test_ListCompanyInactiveCenterReverts() public {
        vm.prank(admin);
        instance.setCenterActive(DigitalTradeExchange.Center.Echo, false);

        vm.prank(company1Reg);
        vm.expectRevert("DTX: center inactive");
        instance.listCompany("Corp", "CORP", "Sector", DigitalTradeExchange.Center.Echo, 1000, 1e18);
    }

    function test_GetCompanyByTicker() public {
        _listCompany(company1Reg, "TECH", DigitalTradeExchange.Center.Charlie);

        (DigitalTradeExchange.Company memory c, uint256 id) = instance.getCompanyByTicker("TECH");
        assertEq(c.ticker, "TECH");
        assertEq(id, 0);
    }

    function test_GetCompanyByUnknownTickerReverts() public {
        vm.expectRevert("DTX: ticker not found");
        instance.getCompanyByTicker("UNKNOWN");
    }

    // ── Delist Company ──────────────────────────────────────────────────────

    function test_DelistCompany() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);

        vm.prank(company1Reg);
        instance.delistCompany(0);

        DigitalTradeExchange.Company memory c = instance.getCompany(0);
        assertFalse(c.listed);
        assertEq(instance.getAllCenters()[0].totalListings, 0);
    }

    function test_DelistNonRegistrantReverts() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);

        vm.prank(unauthorized);
        vm.expectRevert("DTX: unauthorized");
        instance.delistCompany(0);
    }

    function test_OwnerCanDelistAny() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);

        vm.prank(admin);
        instance.delistCompany(0);

        assertFalse(instance.getCompany(0).listed);
    }

    // ── Trader Authorization ────────────────────────────────────────────────

    function test_AuthorizeTrader() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);

        vm.prank(company1Reg);
        instance.authorizeTrader(0, buyer);

        assertTrue(instance.authorizedTraders(0, buyer));
    }

    function test_AuthorizeTraderNonRegistrantReverts() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);

        vm.prank(unauthorized);
        vm.expectRevert("DTX: unauthorized");
        instance.authorizeTrader(0, buyer);
    }

    // ── Execute Trade ───────────────────────────────────────────────────────

    function test_ExecuteTrade() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);

        // Authorize buyer and seller
        vm.prank(company1Reg);
        instance.authorizeTrader(0, buyer);
        vm.prank(company1Reg);
        instance.authorizeTrader(0, seller);

        vm.prank(buyer);
        instance.executeTrade(0, seller, 10_000, 12 * 1e18); // buy 10K shares at $12

        assertEq(instance.tradeCount(), 1);

        DigitalTradeExchange.Company memory c = instance.getCompany(0);
        assertEq(c.priceOICD, 12 * 1e18); // price updated

        // Check trade record
        DigitalTradeExchange.TradeRecord[] memory recent = instance.getRecentTrades(1);
        assertEq(recent[0].buyer, buyer);
        assertEq(recent[0].seller, seller);
        assertEq(recent[0].shares, 10_000);
        assertEq(recent[0].priceOICD, 12 * 1e18);
    }

    function test_TradeUnauthorizedBuyerReverts() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);
        vm.prank(company1Reg);
        instance.authorizeTrader(0, seller);

        vm.prank(buyer); // buyer not authorized
        vm.expectRevert("DTX: buyer not authorized");
        instance.executeTrade(0, seller, 100, 10 * 1e18);
    }

    function test_TradeUnauthorizedSellerReverts() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);
        vm.prank(company1Reg);
        instance.authorizeTrader(0, buyer);

        vm.prank(buyer);
        vm.expectRevert("DTX: seller not authorized");
        instance.executeTrade(0, seller, 100, 10 * 1e18); // seller not authorized
    }

    function test_TradeDelistedCompanyReverts() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);
        vm.prank(company1Reg);
        instance.authorizeTrader(0, buyer);
        vm.prank(company1Reg);
        instance.authorizeTrader(0, seller);
        vm.prank(company1Reg);
        instance.delistCompany(0);

        vm.prank(buyer);
        vm.expectRevert("DTX: company not listed");
        instance.executeTrade(0, seller, 100, 10 * 1e18);
    }

    // ── Price Update ────────────────────────────────────────────────────────

    function test_UpdatePrice() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);

        vm.prank(admin);
        instance.updatePrice(0, 15 * 1e18);

        DigitalTradeExchange.Company memory c = instance.getCompany(0);
        assertEq(c.priceOICD, 15 * 1e18);
        assertEq(c.marketCap, (1_000_000_000 * 15 * 1e18) / 1e18);
    }

    function test_UpdatePriceNonOwnerReverts() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);

        vm.prank(company1Reg);
        vm.expectRevert();
        instance.updatePrice(0, 15 * 1e18);
    }

    // ── Center Management ───────────────────────────────────────────────────

    function test_SetCenterActive() public {
        vm.prank(admin);
        instance.setCenterActive(DigitalTradeExchange.Center.Delta, false);

        assertFalse(instance.getAllCenters()[3].active);
    }

    function test_ReactivateCenter() public {
        vm.prank(admin);
        instance.setCenterActive(DigitalTradeExchange.Center.Delta, false);
        vm.prank(admin);
        instance.setCenterActive(DigitalTradeExchange.Center.Delta, true);

        assertTrue(instance.getAllCenters()[3].active);
    }

    // ── Fee Management ──────────────────────────────────────────────────────

    function test_SetListingFee() public {
        vm.prank(admin);
        instance.setListingFee(50_000 * 1e18);
        assertEq(instance.listingFeeOICD(), 50_000 * 1e18);
    }

    function test_SetTradingFee() public {
        vm.prank(admin);
        instance.setTradingFee(15); // 0.15%
        assertEq(instance.tradingFeesBps(), 15);
    }

    // ── Center Listings ─────────────────────────────────────────────────────

    function test_GetCenterListings() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);
        _listCompany(company2Reg, "BETA", DigitalTradeExchange.Center.Alpha);

        uint256[] memory listings = instance.getCenterListings(0); // Alpha = 0
        assertEq(listings.length, 2);
        assertEq(listings[0], 0);
        assertEq(listings[1], 1);
    }

    // ── Recent Trades ───────────────────────────────────────────────────────

    function test_GetRecentTrades() public {
        _listCompany(company1Reg, "ACME", DigitalTradeExchange.Center.Alpha);

        vm.prank(company1Reg);
        instance.authorizeTrader(0, buyer);
        vm.prank(company1Reg);
        instance.authorizeTrader(0, seller);

        vm.prank(buyer);
        instance.executeTrade(0, seller, 100, 10 * 1e18);
        vm.prank(buyer);
        instance.executeTrade(0, seller, 200, 11 * 1e18);

        DigitalTradeExchange.TradeRecord[] memory recent = instance.getRecentTrades(2);
        assertEq(recent.length, 2);
        assertEq(recent[1].shares, 200); // most recent last
    }

    function test_GetRecentTradesCountCapped() public view {
        // No trades → should return empty
        DigitalTradeExchange.TradeRecord[] memory recent = instance.getRecentTrades(10);
        assertEq(recent.length, 0);
    }
}
