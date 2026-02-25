// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/DigitalTradeBlocks.sol";

contract DigitalTradeBlocksTest is Test {
    DigitalTradeBlocks instance;
    address admin = address(1);
    address issuer = address(2);
    address investor1 = address(3);
    address investor2 = address(4);
    address appraiser = address(5);

    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant APPRAISER_ROLE = keccak256("APPRAISER_ROLE");

    function setUp() public {
        DigitalTradeBlocks impl = new DigitalTradeBlocks();
        bytes memory init = abi.encodeCall(
            DigitalTradeBlocks.initialize,
            ("Digital Trade Blocks", "DTB", admin)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = DigitalTradeBlocks(address(proxy));

        // Grant issuer & appraiser roles
        vm.prank(admin);
        instance.grantRole(ISSUER_ROLE, issuer);
        vm.prank(admin);
        instance.grantRole(APPRAISER_ROLE, appraiser);
    }

    // ── Initialization ──────────────────────────────────────────────────────

    function test_AdminHasAllRoles() public view {
        assertTrue(instance.hasRole(ADMIN_ROLE, admin));
        assertTrue(instance.hasRole(ISSUER_ROLE, admin));
        assertTrue(instance.hasRole(APPRAISER_ROLE, admin));
    }

    function test_ERC721Metadata() public view {
        assertEq(instance.name(), "Digital Trade Blocks");
        assertEq(instance.symbol(), "DTB");
    }

    // ── Create Trade Block ──────────────────────────────────────────────────

    function _createTradeBlock(address creator) internal returns (uint256 tokenId) {
        vm.prank(creator);
        tokenId = instance.createTradeBlock(
            DigitalTradeBlocks.TradeBlockType.InfrastructureBonds,
            "Infrastructure Bond Series A",
            "Sovereign-backed infrastructure financing",
            10_000_000 * 1e18, // faceValue
            block.timestamp + 365 days,
            500, // yieldRate 5%
            "ipfs://QmAssetHash",
            100_000 * 1e18, // minimumInvestment
            "Puerto Rico",
            true
        );
    }

    function test_CreateTradeBlock() public {
        uint256 tokenId = _createTradeBlock(issuer);

        assertEq(tokenId, 1);
        assertEq(instance.blockCounter(), 1);
        assertEq(instance.totalTradeBlockValue(), 10_000_000 * 1e18);
        assertEq(instance.ownerOf(tokenId), issuer);

        (
            DigitalTradeBlocks.TradeBlockType blockType,
            string memory name,
            address blkIssuer,
            uint256 faceValue,
            uint256 currentValue,
            ,
            DigitalTradeBlocks.TradeBlockStatus status,
            uint256 totalInvestment
        ) = instance.getTradeBlock(tokenId);

        assertEq(uint8(blockType), uint8(DigitalTradeBlocks.TradeBlockType.InfrastructureBonds));
        assertEq(name, "Infrastructure Bond Series A");
        assertEq(blkIssuer, issuer);
        assertEq(faceValue, 10_000_000 * 1e18);
        assertEq(currentValue, 10_000_000 * 1e18);
        assertEq(uint8(status), uint8(DigitalTradeBlocks.TradeBlockStatus.Active));
        assertEq(totalInvestment, 0);
    }

    function test_CreateTradeBlockNonIssuerReverts() public {
        vm.prank(investor1);
        vm.expectRevert();
        instance.createTradeBlock(
            DigitalTradeBlocks.TradeBlockType.SovereignDebt,
            "Debt Block",
            "desc",
            1_000_000 * 1e18,
            block.timestamp + 180 days,
            300,
            "ipfs://hash",
            0,
            "US",
            false
        );
    }

    function test_CreateTradeBlockInvalidFaceValueReverts() public {
        vm.prank(issuer);
        vm.expectRevert("Invalid face value");
        instance.createTradeBlock(
            DigitalTradeBlocks.TradeBlockType.DebtSecurities,
            "Zero Block",
            "desc",
            0, // invalid
            block.timestamp + 365 days,
            100,
            "ipfs://hash",
            0,
            "US",
            false
        );
    }

    function test_CreateTradeBlockInvalidMaturityReverts() public {
        vm.prank(issuer);
        vm.expectRevert("Invalid maturity date");
        instance.createTradeBlock(
            DigitalTradeBlocks.TradeBlockType.CorporateDebt,
            "Expired Block",
            "desc",
            1_000_000 * 1e18,
            block.timestamp - 1, // in the past
            300,
            "",
            0,
            "US",
            false
        );
    }

    // ── Invest in Trade Block ───────────────────────────────────────────────

    function test_InvestInFractionalTradeBlock() public {
        uint256 tokenId = _createTradeBlock(issuer);

        vm.deal(investor1, 1_000_000 ether);
        vm.prank(investor1);
        instance.investInTradeBlock{value: 200_000 * 1e18}(tokenId);

        assertEq(instance.getInvestorShare(tokenId, investor1), 200_000 * 1e18);

        address[] memory investors = instance.getInvestors(tokenId);
        assertEq(investors.length, 1);
        assertEq(investors[0], investor1);
    }

    function test_MultipleInvestorsInOneBlock() public {
        uint256 tokenId = _createTradeBlock(issuer);

        vm.deal(investor1, 1_000_000 ether);
        vm.deal(investor2, 1_000_000 ether);

        vm.prank(investor1);
        instance.investInTradeBlock{value: 200_000 * 1e18}(tokenId);

        vm.prank(investor2);
        instance.investInTradeBlock{value: 300_000 * 1e18}(tokenId);

        address[] memory investors = instance.getInvestors(tokenId);
        assertEq(investors.length, 2);
    }

    function test_InvestBelowMinimumReverts() public {
        uint256 tokenId = _createTradeBlock(issuer);

        vm.deal(investor1, 1_000_000 ether);
        vm.prank(investor1);
        vm.expectRevert("Below minimum investment");
        instance.investInTradeBlock{value: 50_000 * 1e18}(tokenId); // below 100_000 min
    }

    function test_InvestInNonFractionalReverts() public {
        vm.prank(issuer);
        uint256 tokenId = instance.createTradeBlock(
            DigitalTradeBlocks.TradeBlockType.SovereignDebt,
            "Non-Frac Block",
            "desc",
            5_000_000 * 1e18,
            block.timestamp + 365 days,
            200,
            "",
            0,
            "US",
            false // NOT fractional
        );

        vm.deal(investor1, 10_000_000 ether);
        vm.prank(investor1);
        vm.expectRevert("Block not fractional");
        instance.investInTradeBlock{value: 1_000_000 * 1e18}(tokenId);
    }

    // ── Offer & Buy ─────────────────────────────────────────────────────────

    function test_OfferTradeBlock() public {
        uint256 tokenId = _createTradeBlock(issuer);

        vm.prank(issuer);
        instance.offerTradeBlock(tokenId, 12_000_000 * 1e18, 30);

        assertEq(instance.offerCounter(), 1);

        (
            ,
            uint256 _offerTokenId,
            address _offerSeller,
            uint256 _offerPrice,
            bool _offerActive,

        ) = instance.offers(1);
        assertEq(_offerTokenId, tokenId);
        assertEq(_offerSeller, issuer);
        assertEq(_offerPrice, 12_000_000 * 1e18);
        assertTrue(_offerActive);
    }

    function test_OfferByNonOwnerReverts() public {
        uint256 tokenId = _createTradeBlock(issuer);

        vm.prank(investor1);
        vm.expectRevert("Not owner");
        instance.offerTradeBlock(tokenId, 10_000_000 * 1e18, 30);
    }

    function test_BuyTradeBlock() public {
        uint256 tokenId = _createTradeBlock(issuer);

        vm.prank(issuer);
        instance.offerTradeBlock(tokenId, 12_000_000 * 1e18, 30);

        vm.deal(investor1, 100_000_000 ether);
        vm.prank(investor1);
        instance.buyTradeBlock{value: 12_000_000 * 1e18}(1);

        assertEq(instance.ownerOf(tokenId), investor1);

        (
            ,
            ,
            ,
            ,
            bool _buyOfferActive,

        ) = instance.offers(1);
        assertFalse(_buyOfferActive);
    }

    function test_BuyExpiredOfferReverts() public {
        uint256 tokenId = _createTradeBlock(issuer);

        vm.prank(issuer);
        instance.offerTradeBlock(tokenId, 10_000_000 * 1e18, 1); // 1 day

        vm.warp(block.timestamp + 2 days);

        vm.deal(investor1, 100_000_000 ether);
        vm.prank(investor1);
        vm.expectRevert("Offer expired");
        instance.buyTradeBlock{value: 10_000_000 * 1e18}(1);
    }

    // ── Update Value ────────────────────────────────────────────────────────

    function test_UpdateTradeBlockValue() public {
        uint256 tokenId = _createTradeBlock(issuer);
        uint256 newValue = 11_000_000 * 1e18;

        vm.prank(appraiser);
        instance.updateTradeBlockValue(tokenId, newValue);

        (, , , , uint256 currentValue, , , ) = instance.getTradeBlock(tokenId);
        assertEq(currentValue, newValue);
        assertEq(instance.totalTradeBlockValue(), newValue);
    }

    function test_UpdateValueNonAppraiserReverts() public {
        uint256 tokenId = _createTradeBlock(issuer);

        vm.prank(investor1);
        vm.expectRevert();
        instance.updateTradeBlockValue(tokenId, 5_000_000 * 1e18);
    }

    // ── Pause / Unpause ─────────────────────────────────────────────────────

    function test_PausePreventsMinting() public {
        vm.prank(admin);
        instance.pause();

        vm.prank(issuer);
        vm.expectRevert();
        instance.createTradeBlock(
            DigitalTradeBlocks.TradeBlockType.CorporateDebt,
            "Paused Block",
            "desc",
            1_000_000 * 1e18,
            block.timestamp + 365 days,
            300,
            "",
            0,
            "US",
            false
        );
    }

    function test_UnpauseRestoresMinting() public {
        vm.prank(admin);
        instance.pause();
        vm.prank(admin);
        instance.unpause();

        uint256 tokenId = _createTradeBlock(issuer);
        assertEq(tokenId, 1);
    }

    // ── Views ──────────────────────────────────────────────────────────────

    function test_GetOwnerBlocks() public {
        _createTradeBlock(issuer);
        _createTradeBlock(issuer);

        uint256[] memory blocks = instance.getOwnerBlocks(issuer);
        assertEq(blocks.length, 2);
    }

    function test_SupportsInterface() public view {
        // ERC721 interfaceId
        assertTrue(instance.supportsInterface(0x80ac58cd));
        // AccessControl interfaceId
        assertTrue(instance.supportsInterface(0x7965db0b));
    }
}
