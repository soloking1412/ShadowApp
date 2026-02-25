// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/DCMMarketCharter.sol";

contract DCMMarketCharterTest is Test {
    DCMMarketCharter instance;
    address admin = address(1);
    address subscriber1 = address(2);
    address subscriber2 = address(3);
    address reporter = address(4);

    function setUp() public {
        DCMMarketCharter impl = new DCMMarketCharter();
        bytes memory init = abi.encodeCall(DCMMarketCharter.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = DCMMarketCharter(address(proxy));
    }

    // ── Initialization ──────────────────────────────────────────────────────

    function test_InitialConstants() public view {
        assertEq(instance.PILLARS(), 4);
        assertEq(instance.METRICS(), 4);
        assertEq(instance.MAX_SCORE(), 400);
    }

    function test_InitialFees() public view {
        assertEq(instance.retailFeePerMonth(), 3 * 1e18);
        assertEq(instance.institutionalFeePerMonth(), 8 * 1e18);
        assertEq(instance.transactionFeeBps(), 9);
    }

    function test_InitialPillarNames() public view {
        (string memory p1Name, , , ) = instance.getPillar(0);
        (string memory p2Name, , , ) = instance.getPillar(1);
        (string memory p3Name, , , ) = instance.getPillar(2);
        (string memory p4Name, , , ) = instance.getPillar(3);

        assertEq(p1Name, "Public Market Health");
        assertEq(p2Name, "Global Market Health");
        assertEq(p3Name, "Corporate Financial Health");
        assertEq(p4Name, "Public Financial Health");
    }

    function test_InitialScoresCalculated() public view {
        // Pillar 1: 75+80+70+65=290, 290/4=72 (integer truncation)
        // Pillar 2: 72+68+85+77=302, 302/4=75
        // Pillar 3: 73+60+78+82=293, 293/4=73
        // Pillar 4: 76+71+74+79=300, 300/4=75
        (uint16 total, uint8 p1, uint8 p2, uint8 p3, uint8 p4) = instance.getCurrentScore();
        assertEq(uint256(p1), 72);
        assertEq(uint256(p2), 75);
        assertEq(uint256(p3), 73);
        assertEq(uint256(p4), 75);
        assertEq(uint256(total), 295);
    }

    // ── Update Metric ───────────────────────────────────────────────────────

    function test_UpdateSingleMetric() public {
        vm.prank(admin);
        instance.updateMetric(0, 0, 90); // Pillar 1, Metric 0, score = 90

        (, uint8 pillar1Score, , ) = instance.getPillar(0);
        // Old metrics: 75, 80, 70, 65. Updated metric 0 to 90: (90+80+70+65)=305, 305/4=76
        assertEq(uint256(pillar1Score), 76);
    }

    function test_UpdateMetricPillar3() public {
        vm.prank(admin);
        instance.updateMetric(2, 2, 95); // Corporate - Dividend Yield

        (, uint8 p3Score, , ) = instance.getPillar(2);
        // (73+60+95+82)=310, 310/4=77
        assertEq(uint256(p3Score), 77);
    }

    function test_UpdateMetricAbove100Reverts() public {
        vm.prank(admin);
        vm.expectRevert("DCM: score > 100");
        instance.updateMetric(0, 0, 101);
    }

    function test_UpdateMetricInvalidPillarReverts() public {
        vm.prank(admin);
        vm.expectRevert("DCM: invalid pillar");
        instance.updateMetric(4, 0, 80); // pillar index 4 is out of bounds
    }

    function test_UpdateMetricInvalidMetricReverts() public {
        vm.prank(admin);
        vm.expectRevert("DCM: invalid metric");
        instance.updateMetric(0, 4, 80); // metric index 4 is out of bounds
    }

    function test_UpdateMetricNonOwnerReverts() public {
        vm.prank(reporter);
        vm.expectRevert();
        instance.updateMetric(0, 0, 80);
    }

    // ── Batch Update All Metrics ────────────────────────────────────────────

    function test_UpdateAllMetrics() public {
        uint8[16] memory scores = [
            uint8(100), 100, 100, 100, // Pillar 1: all 100
            uint8(50),  50,  50,  50,  // Pillar 2: all 50
            uint8(80),  80,  80,  80,  // Pillar 3: all 80
            uint8(60),  60,  60,  60   // Pillar 4: all 60
        ];

        vm.prank(admin);
        instance.updateAllMetrics(scores);

        (uint16 total, uint8 p1, uint8 p2, uint8 p3, uint8 p4) = instance.getCurrentScore();
        assertEq(uint256(p1), 100);
        assertEq(uint256(p2), 50);
        assertEq(uint256(p3), 80);
        assertEq(uint256(p4), 60);
        assertEq(uint256(total), 290);
    }

    function test_UpdateAllMetricsAbove100Reverts() public {
        uint8[16] memory scores = [
            uint8(101), 100, 100, 100,
            uint8(50),  50,  50,  50,
            uint8(80),  80,  80,  80,
            uint8(60),  60,  60,  60
        ];

        vm.prank(admin);
        vm.expectRevert("DCM: score > 100");
        instance.updateAllMetrics(scores);
    }

    // ── Publish Report ──────────────────────────────────────────────────────

    function test_PublishReport() public {
        uint256 reportId = instance.publishReport();
        assertEq(reportId, 0); // first report, 0-indexed

        assertEq(instance.reportCount(), 1);

        DCMMarketCharter.HealthReport memory report = instance.getReport(0);
        assertGt(report.totalScore, 0);
        assertEq(report.reportedBy, address(this));
        assertGt(report.reportedAt, 0);
    }

    function test_PublishReportAfterUpdate() public {
        // Set all metrics to 100
        uint8[16] memory scores;
        for (uint256 i = 0; i < 16; i++) {
            scores[i] = 100;
        }
        vm.prank(admin);
        instance.updateAllMetrics(scores);

        instance.publishReport();

        DCMMarketCharter.HealthReport memory report = instance.getReport(0);
        assertEq(report.totalScore, 400); // perfect score
        assertEq(report.pillar1, 100);
        assertEq(report.pillar2, 100);
        assertEq(report.pillar3, 100);
        assertEq(report.pillar4, 100);
    }

    function test_MultipleReports() public {
        instance.publishReport();
        instance.publishReport();
        assertEq(instance.reportCount(), 2);
    }

    // ── Subscriptions ───────────────────────────────────────────────────────

    function test_SubscribeRetail() public {
        vm.prank(admin);
        instance.subscribe(subscriber1, 1, 3); // tier 1, 3 months

        assertTrue(instance.isActiveSubscriber(subscriber1));

        // Subscriber: (bool active, uint8 tier, uint256 expiresAt)
        (bool sub_active, uint8 sub_tier, uint256 sub_expiresAt) = instance.subscribers(subscriber1);
        assertTrue(sub_active);
        assertEq(uint256(sub_tier), 1);
        assertGt(sub_expiresAt, block.timestamp);
    }

    function test_SubscribeInstitutional() public {
        vm.prank(admin);
        instance.subscribe(subscriber2, 2, 12); // tier 2, 12 months

        (, uint8 sub2_tier, ) = instance.subscribers(subscriber2);
        assertEq(uint256(sub2_tier), 2);
    }

    function test_SubscriptionExpires() public {
        vm.prank(admin);
        instance.subscribe(subscriber1, 1, 1); // 1 month

        vm.warp(block.timestamp + 31 days);

        assertFalse(instance.isActiveSubscriber(subscriber1));
    }

    function test_RenewSubscription() public {
        vm.prank(admin);
        instance.subscribe(subscriber1, 1, 1);

        (, , uint256 initialExpiry) = instance.subscribers(subscriber1);

        vm.prank(admin);
        instance.subscribe(subscriber1, 1, 1); // renew

        (, , uint256 renewedExpiry) = instance.subscribers(subscriber1);
        assertGt(renewedExpiry, initialExpiry); // expiry extended
    }

    function test_SubscribeInvalidTierReverts() public {
        vm.prank(admin);
        vm.expectRevert("DCM: invalid tier");
        instance.subscribe(subscriber1, 3, 1); // tier 3 doesn't exist
    }

    function test_SubscribeZeroMonthsReverts() public {
        vm.prank(admin);
        vm.expectRevert("DCM: zero months");
        instance.subscribe(subscriber1, 1, 0);
    }

    function test_SubscribeNonOwnerReverts() public {
        vm.prank(reporter);
        vm.expectRevert();
        instance.subscribe(subscriber1, 1, 3);
    }

    // ── Set Fees ────────────────────────────────────────────────────────────

    function test_SetFees() public {
        vm.prank(admin);
        instance.setFees(5 * 1e18, 15 * 1e18);

        assertEq(instance.retailFeePerMonth(), 5 * 1e18);
        assertEq(instance.institutionalFeePerMonth(), 15 * 1e18);
    }

    function test_SetFeesNonOwnerReverts() public {
        vm.prank(reporter);
        vm.expectRevert();
        instance.setFees(5 * 1e18, 15 * 1e18);
    }

    // ── Get Pillar Details ──────────────────────────────────────────────────

    function test_GetPillarMetrics() public view {
        (, , string[4] memory names, uint8[4] memory scores) = instance.getPillar(0);

        assertEq(names[0], "Market Liquidity Index");
        assertEq(names[1], "Price Discovery Efficiency");
        assertEq(names[2], "Volatility Index");
        assertEq(names[3], "Trading Volume Growth");

        assertEq(scores[0], 75);
        assertEq(scores[1], 80);
        assertEq(scores[2], 70);
        assertEq(scores[3], 65);
    }
}
