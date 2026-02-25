// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/OrionScore.sol";

contract OrionScoreTest is Test {
    OrionScore instance;

    address owner   = address(1);
    address analyst = address(2);
    address nobody  = address(3);

    // Seeded countries from _seedEmergingMarkets
    string constant SEED_COUNTRY = "AR"; // Argentina is in seed list
    string constant NEW_COUNTRY  = "JP"; // Japan is NOT in seed list

    function setUp() public {
        OrionScore impl = new OrionScore();
        bytes memory init = abi.encodeCall(OrionScore.initialize, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = OrionScore(address(proxy));

        // Authorize analyst
        vm.prank(owner);
        instance.authorizeAnalyst(analyst, true);
    }

    // -----------------------------------------------------------------------
    // 1. Initialization
    // -----------------------------------------------------------------------
    function test_Initialization() public view {
        assertEq(instance.owner(), owner);
        // 20 seed countries initialized
        assertEq(instance.countryCount(), 20);
    }

    function test_WeightsInitialized() public view {
        uint8[9] memory w = instance.getWeights();
        // Currency=5, Inflation=5, Banking=8, Dividend=8, Credit=12, EPS=10, Financial=12, Cashflow=15, Systemic=25
        assertEq(w[uint8(OrionScore.Variable.Currency)],   5);
        assertEq(w[uint8(OrionScore.Variable.Inflation)],  5);
        assertEq(w[uint8(OrionScore.Variable.Banking)],    8);
        assertEq(w[uint8(OrionScore.Variable.Dividend)],   8);
        assertEq(w[uint8(OrionScore.Variable.Credit)],     12);
        assertEq(w[uint8(OrionScore.Variable.EPS)],        10);
        assertEq(w[uint8(OrionScore.Variable.Financial)],  12);
        assertEq(w[uint8(OrionScore.Variable.Cashflow)],   15);
        assertEq(w[uint8(OrionScore.Variable.Systemic)],   25);

        // Weights sum to 100
        uint256 sum = 0;
        for (uint8 i = 0; i < 9; i++) {
            sum += w[i];
        }
        assertEq(sum, 100);
    }

    function test_SeedCountriesExist() public view {
        string[20] memory seeded = [
            "LK","VE","SD","ZW","AR","SS","IR","ET","AO","YE",
            "LY","TR","NG","HT","BR","BY","GH","PK","BD","MX"
        ];
        for (uint256 i = 0; i < seeded.length; i++) {
            OrionScore.CountryScore memory cs = instance.getCountryScore(seeded[i]);
            assertTrue(cs.exists, string(abi.encodePacked("Not exists: ", seeded[i])));
        }
    }

    function test_AllCountriesListHas20Entries() public view {
        string[] memory countries = instance.getAllCountries();
        assertEq(countries.length, 20);
    }

    // -----------------------------------------------------------------------
    // 2. Analyst Management
    // -----------------------------------------------------------------------
    function test_AuthorizeAnalyst() public {
        address newAnalyst = address(10);

        vm.expectEmit(false, false, false, true);
        emit OrionScore.AnalystAuthorized(newAnalyst, true);

        vm.prank(owner);
        instance.authorizeAnalyst(newAnalyst, true);
        assertTrue(instance.analysts(newAnalyst));
    }

    function test_RevokeAnalyst() public {
        vm.prank(owner);
        instance.authorizeAnalyst(analyst, false);
        assertFalse(instance.analysts(analyst));
    }

    function test_AuthorizeAnalyst_Reverts_NonOwner() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.authorizeAnalyst(address(10), true);
    }

    // -----------------------------------------------------------------------
    // 3. Country Registration
    // -----------------------------------------------------------------------
    function test_RegisterCountry() public {
        vm.prank(owner);
        instance.registerCountry(NEW_COUNTRY, "Japan");

        OrionScore.CountryScore memory cs = instance.getCountryScore(NEW_COUNTRY);
        assertTrue(cs.exists);
        assertEq(cs.code, NEW_COUNTRY);
        assertEq(cs.name, "Japan");
        assertEq(instance.countryCount(), 21);
    }

    function test_RegisterCountry_NoDuplicateCount() public {
        // SEED_COUNTRY already seeded; re-registering should be a no-op
        uint256 countBefore = instance.countryCount();

        vm.prank(owner);
        instance.registerCountry(SEED_COUNTRY, "Argentina Again");

        // countryCount should not change
        assertEq(instance.countryCount(), countBefore);
    }

    function test_RegisterCountry_Reverts_NonOwner() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.registerCountry("JP", "Japan");
    }

    // -----------------------------------------------------------------------
    // 4. Full Country Scoring
    // -----------------------------------------------------------------------
    function _buildScores(uint8 value) internal pure returns (uint8[9] memory scores) {
        for (uint8 i = 0; i < 9; i++) {
            scores[i] = value;
        }
    }

    function _buildRationales(string memory text) internal pure returns (string[9] memory rationales) {
        for (uint8 i = 0; i < 9; i++) {
            rationales[i] = text;
        }
    }

    function test_ScoreCountry_HighScore() public {
        // All scores = 80 → composite = (80 * 100) / 100 = 80 → tier 4
        uint8[9] memory scores = _buildScores(80);
        string[9] memory rationales = _buildRationales("Strong");

        vm.expectEmit(true, false, false, true);
        emit OrionScore.CountryScored(SEED_COUNTRY, 80, true);

        vm.prank(analyst);
        instance.scoreCountry(SEED_COUNTRY, scores, rationales);

        OrionScore.CountryScore memory cs = instance.getCountryScore(SEED_COUNTRY);
        assertEq(cs.compositeScore, 80);
        assertTrue(cs.approved);
        assertEq(cs.allocationTier, 4);
        assertEq(cs.debtMultiplier, 450);
    }

    function test_ScoreCountry_MidScore_Tier3() public {
        // composite = 65 → tier 3
        uint8[9] memory scores = _buildScores(65);
        string[9] memory rationales = _buildRationales("Good");

        vm.prank(analyst);
        instance.scoreCountry(SEED_COUNTRY, scores, rationales);

        OrionScore.CountryScore memory cs = instance.getCountryScore(SEED_COUNTRY);
        assertEq(cs.allocationTier, 3);
        assertEq(cs.debtMultiplier, 350);
    }

    function test_ScoreCountry_MidScore_Tier2() public {
        // composite = 50 → tier 2
        uint8[9] memory scores = _buildScores(50);
        string[9] memory rationales = _buildRationales("Neutral");

        vm.prank(analyst);
        instance.scoreCountry(SEED_COUNTRY, scores, rationales);

        OrionScore.CountryScore memory cs = instance.getCountryScore(SEED_COUNTRY);
        assertEq(cs.allocationTier, 2);
        assertEq(cs.debtMultiplier, 250);
        assertTrue(cs.approved);
    }

    function test_ScoreCountry_LowScore_Tier1_NotApproved() public {
        // composite = 30 → tier 1, not approved
        uint8[9] memory scores = _buildScores(30);
        string[9] memory rationales = _buildRationales("Weak");

        vm.prank(analyst);
        instance.scoreCountry(SEED_COUNTRY, scores, rationales);

        OrionScore.CountryScore memory cs = instance.getCountryScore(SEED_COUNTRY);
        assertEq(cs.allocationTier, 1);
        assertEq(cs.debtMultiplier, 150);
        assertFalse(cs.approved);
    }

    function test_ScoreCountry_RecordsHistory() public {
        uint8[9] memory scores = _buildScores(60);
        string[9] memory rationales = _buildRationales("Good");

        vm.prank(analyst);
        instance.scoreCountry(SEED_COUNTRY, scores, rationales);

        vm.warp(block.timestamp + 1 days);

        uint8[9] memory scores2 = _buildScores(70);
        vm.prank(analyst);
        instance.scoreCountry(SEED_COUNTRY, scores2, rationales);

        OrionScore.ScoreHistory[] memory hist = instance.getScoreHistory(SEED_COUNTRY);
        assertEq(hist.length, 2);
        assertEq(hist[0].compositeScore, 60);
        assertEq(hist[1].compositeScore, 70);
        assertEq(hist[0].analyst, analyst);
    }

    function test_ScoreCountry_Reverts_UnregisteredCountry() public {
        uint8[9] memory scores = _buildScores(50);
        string[9] memory rationales = _buildRationales("OK");

        vm.prank(analyst);
        vm.expectRevert("Country not registered");
        instance.scoreCountry("XX", scores, rationales);
    }

    function test_ScoreCountry_Reverts_ScoreOver100() public {
        uint8[9] memory scores = _buildScores(50);
        scores[0] = 101; // invalid

        string[9] memory rationales = _buildRationales("OK");

        vm.prank(analyst);
        vm.expectRevert("Score 0-100");
        instance.scoreCountry(SEED_COUNTRY, scores, rationales);
    }

    function test_ScoreCountry_Reverts_NonAnalyst() public {
        uint8[9] memory scores = _buildScores(50);
        string[9] memory rationales = _buildRationales("OK");

        vm.prank(nobody);
        vm.expectRevert("Not authorized analyst");
        instance.scoreCountry(SEED_COUNTRY, scores, rationales);
    }

    // Owner can also score (bypasses onlyAnalyst check)
    function test_ScoreCountry_OwnerCanScore() public {
        uint8[9] memory scores = _buildScores(75);
        string[9] memory rationales = _buildRationales("Sovereign");

        vm.prank(owner);
        instance.scoreCountry(SEED_COUNTRY, scores, rationales);

        OrionScore.CountryScore memory cs = instance.getCountryScore(SEED_COUNTRY);
        assertEq(cs.compositeScore, 75);
    }

    // -----------------------------------------------------------------------
    // 5. Variable Update
    // -----------------------------------------------------------------------
    function test_UpdateVariable() public {
        // First give a baseline score
        uint8[9] memory scores = _buildScores(50);
        string[9] memory rationales = _buildRationales("Base");
        vm.prank(analyst);
        instance.scoreCountry(SEED_COUNTRY, scores, rationales);

        vm.expectEmit(true, false, false, true);
        emit OrionScore.VariableUpdated(SEED_COUNTRY, OrionScore.Variable.Systemic, 90);

        vm.prank(analyst);
        instance.updateVariable(
            SEED_COUNTRY,
            OrionScore.Variable.Systemic,
            90,
            "System stability improved"
        );

        (uint8 score, string memory rationale, ) =
            instance.getVariableScore(SEED_COUNTRY, OrionScore.Variable.Systemic);
        assertEq(score, 90);
        assertEq(rationale, "System stability improved");

        // Composite should be recalculated
        OrionScore.CountryScore memory cs = instance.getCountryScore(SEED_COUNTRY);
        // New composite: (50*77 + 90*25 - 50*25) / 100 = (3850 + 2250 - 1250) / 100
        // Actually: 8 vars * 50 = weighted_sum_without_systemic, systemic changed from 50 to 90
        // Old composite = 50. New: 50*100 - 50*25 + 90*25 = 5000 - 1250 + 2250 = 6000 → /100 = 60
        assertEq(cs.compositeScore, 60);
    }

    function test_UpdateVariable_Reverts_ScoreOver100() public {
        vm.prank(analyst);
        vm.expectRevert("Score 0-100");
        instance.updateVariable(SEED_COUNTRY, OrionScore.Variable.Inflation, 101, "Too high");
    }

    function test_UpdateVariable_Reverts_UnregisteredCountry() public {
        vm.prank(analyst);
        vm.expectRevert("Country not registered");
        instance.updateVariable("ZZ", OrionScore.Variable.Inflation, 50, "N/A");
    }

    function test_UpdateVariable_Reverts_NonAnalyst() public {
        vm.prank(nobody);
        vm.expectRevert("Not authorized analyst");
        instance.updateVariable(SEED_COUNTRY, OrionScore.Variable.Inflation, 50, "N/A");
    }

    // -----------------------------------------------------------------------
    // 6. Views
    // -----------------------------------------------------------------------
    function test_GetCountryScore() public view {
        OrionScore.CountryScore memory cs = instance.getCountryScore(SEED_COUNTRY);
        assertTrue(cs.exists);
        assertEq(cs.code, SEED_COUNTRY);
    }

    function test_GetVariableScore() public view {
        (uint8 score, , ) =
            instance.getVariableScore(SEED_COUNTRY, OrionScore.Variable.Currency);
        // Initial seeded score is 0
        assertEq(score, 0);
    }

    function test_GetApprovedCountries_EmptyInitially() public view {
        // All seeded countries have composite 0 (no scores submitted), so none approved
        string[] memory approved = instance.getApprovedCountries();
        assertEq(approved.length, 0);
    }

    function test_GetApprovedCountries_AfterScoring() public {
        uint8[9] memory scores = _buildScores(80);
        string[9] memory rationales = _buildRationales("Excellent");

        vm.prank(analyst);
        instance.scoreCountry("AR", scores, rationales);

        vm.prank(analyst);
        instance.scoreCountry("BR", scores, rationales);

        string[] memory approved = instance.getApprovedCountries();
        assertEq(approved.length, 2);
    }

    function test_GetScoreHistory_EmptyInitially() public view {
        OrionScore.ScoreHistory[] memory hist = instance.getScoreHistory(SEED_COUNTRY);
        assertEq(hist.length, 0);
    }

    // -----------------------------------------------------------------------
    // 7. Composite Score Calculation Correctness
    // -----------------------------------------------------------------------
    function test_CompositeScoreCalculation() public {
        // Build specific scores and verify composite manually
        uint8[9] memory scores;
        scores[uint8(OrionScore.Variable.Currency)]   = 60;  // weight 5  → 300
        scores[uint8(OrionScore.Variable.Inflation)]  = 50;  // weight 5  → 250
        scores[uint8(OrionScore.Variable.Banking)]    = 70;  // weight 8  → 560
        scores[uint8(OrionScore.Variable.Dividend)]   = 40;  // weight 8  → 320
        scores[uint8(OrionScore.Variable.Credit)]     = 80;  // weight 12 → 960
        scores[uint8(OrionScore.Variable.EPS)]        = 55;  // weight 10 → 550
        scores[uint8(OrionScore.Variable.Financial)]  = 65;  // weight 12 → 780
        scores[uint8(OrionScore.Variable.Cashflow)]   = 75;  // weight 15 → 1125
        scores[uint8(OrionScore.Variable.Systemic)]   = 90;  // weight 25 → 2250
        // sum = 7095, /100 = 70

        string[9] memory rationales = _buildRationales("Analysis");

        vm.prank(analyst);
        instance.scoreCountry("AR", scores, rationales);

        OrionScore.CountryScore memory cs = instance.getCountryScore("AR");
        assertEq(cs.compositeScore, 70);
        assertTrue(cs.approved); // >= 45
        assertEq(cs.allocationTier, 3); // 60 <= 70 < 75
    }

    // -----------------------------------------------------------------------
    // 8. UUPS Upgrade Authorization
    // -----------------------------------------------------------------------
    function test_UpgradeAuthorization_OnlyOwner() public {
        OrionScore newImpl = new OrionScore();

        // Non-owner cannot upgrade
        vm.prank(nobody);
        vm.expectRevert();
        instance.upgradeToAndCall(address(newImpl), "");

        // Owner can upgrade
        vm.prank(owner);
        instance.upgradeToAndCall(address(newImpl), "");
    }
}
