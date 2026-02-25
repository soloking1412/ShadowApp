// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/InfrastructureAssets.sol";

contract InfrastructureAssetsTest is Test {
    InfrastructureAssets instance;

    address admin    = address(1);
    address operator = address(2);
    address shipper  = address(3);
    address investor = address(4);
    address nobody   = address(5);

    string[] emptyCorridors;

    function setUp() public {
        InfrastructureAssets impl = new InfrastructureAssets();
        bytes memory init = abi.encodeCall(InfrastructureAssets.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = InfrastructureAssets(payable(address(proxy)));

        // Grant OPERATOR_ROLE to operator
        bytes32 operatorRole = instance.OPERATOR_ROLE();
        vm.prank(admin);
        instance.grantRole(operatorRole, operator);

        vm.deal(shipper, 100 ether);
        vm.deal(investor, 100 ether);
    }

    // -----------------------------------------------------------------------
    // 1. Initialization
    // -----------------------------------------------------------------------
    function test_Initialization() public view {
        assertTrue(instance.hasRole(instance.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(instance.hasRole(instance.ADMIN_ROLE(), admin));
        assertTrue(instance.hasRole(instance.OPERATOR_ROLE(), admin));
        assertEq(instance.assetCounter(), 0);
        assertEq(instance.corridorCounter(), 0);
        assertEq(instance.movementCounter(), 0);
        assertEq(instance.totalFreightVolume(), 0);
        assertEq(instance.totalFreightValue(), 0);
    }

    // -----------------------------------------------------------------------
    // 2. Asset Registration
    // -----------------------------------------------------------------------
    function test_RegisterAsset() public {
        vm.expectEmit(true, false, false, true);
        emit InfrastructureAssets.AssetRegistered(
            1,
            InfrastructureAssets.AssetType.Seaport,
            "Port of Zayed",
            "AEAUH"
        );

        vm.prank(operator);
        uint256 assetId = instance.registerAsset(
            InfrastructureAssets.AssetType.Seaport,
            "Port of Zayed",
            "AEAUH",
            "AE",
            "Abu Dhabi",
            "24.4539,54.3773",
            10_000_000, // capacity TEU
            emptyCorridors,
            true         // sezEnabled
        );

        assertEq(assetId, 1);
        assertEq(instance.assetCounter(), 1);
        assertEq(instance.codeToAssetId("AEAUH"), 1);

        (
            ,
            InfrastructureAssets.AssetType _assetType,
            string memory _name,
            string memory _code,
            string memory _country,
            string memory _city,
            ,
            uint256 _capacity,
            ,
            InfrastructureAssets.AssetStatus _status,
            ,
            ,
            bool _sezEnabled
        ) = instance.assets(1);
        assertEq(_name, "Port of Zayed");
        assertEq(_code, "AEAUH");
        assertEq(_country, "AE");
        assertEq(_city, "Abu Dhabi");
        assertEq(_capacity, 10_000_000);
        assertEq(uint8(_assetType), uint8(InfrastructureAssets.AssetType.Seaport));
        assertEq(uint8(_status), uint8(InfrastructureAssets.AssetStatus.Active));
        assertTrue(_sezEnabled);
    }

    function test_RegisterAsset_Reverts_EmptyCode() public {
        vm.prank(operator);
        vm.expectRevert("Invalid code");
        instance.registerAsset(
            InfrastructureAssets.AssetType.Airport,
            "Test Airport",
            "",
            "US",
            "New York",
            "40.6413,-73.7781",
            5_000_000,
            emptyCorridors,
            false
        );
    }

    function test_RegisterAsset_Reverts_DuplicateCode() public {
        vm.startPrank(operator);
        instance.registerAsset(
            InfrastructureAssets.AssetType.Seaport,
            "Port A",
            "CODE1",
            "US",
            "New York",
            "40.7,-74.0",
            1_000,
            emptyCorridors,
            false
        );
        vm.expectRevert("Code already exists");
        instance.registerAsset(
            InfrastructureAssets.AssetType.Airport,
            "Airport A",
            "CODE1", // duplicate
            "US",
            "New York",
            "40.7,-74.0",
            1_000,
            emptyCorridors,
            false
        );
        vm.stopPrank();
    }

    function test_RegisterAsset_Reverts_NonOperator() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.registerAsset(
            InfrastructureAssets.AssetType.Airport,
            "Airport",
            "JFK",
            "US",
            "New York",
            "40.6,-73.7",
            1_000,
            emptyCorridors,
            false
        );
    }

    // -----------------------------------------------------------------------
    // 3. Freight Corridors
    // -----------------------------------------------------------------------
    function _registerTwoAssets() internal returns (uint256 portId, uint256 airportId) {
        vm.startPrank(operator);
        portId = instance.registerAsset(
            InfrastructureAssets.AssetType.Seaport,
            "Origin Port",
            "ORIG",
            "US",
            "New York",
            "40.7,-74.0",
            5_000_000,
            emptyCorridors,
            false
        );
        airportId = instance.registerAsset(
            InfrastructureAssets.AssetType.Airport,
            "Destination Airport",
            "DEST",
            "GB",
            "London",
            "51.4,-0.4",
            3_000_000,
            emptyCorridors,
            false
        );
        vm.stopPrank();
    }

    function test_EstablishCorridor() public {
        _registerTwoAssets();

        InfrastructureAssets.FreightType[] memory types = new InfrastructureAssets.FreightType[](2);
        types[0] = InfrastructureAssets.FreightType.Container;
        types[1] = InfrastructureAssets.FreightType.Bulk;

        uint256[] memory transitIds = new uint256[](0);

        vm.expectEmit(true, false, false, true);
        emit InfrastructureAssets.CorridorEstablished(1, "Transatlantic", "ORIG", "DEST");

        vm.prank(operator);
        uint256 corridorId = instance.establishCorridor(
            "Transatlantic",
            "ORIG",
            "DEST",
            transitIds,
            types,
            5500,   // distance km
            336     // avg transit hours
        );

        assertEq(corridorId, 1);
        assertEq(instance.corridorCounter(), 1);

        (string memory name, string memory origin, string memory dest, uint256 dist, uint256 vol, bool active) =
            instance.getCorridor(1);
        assertEq(name, "Transatlantic");
        assertEq(origin, "ORIG");
        assertEq(dest, "DEST");
        assertEq(dist, 5500);
        assertEq(vol, 0);
        assertTrue(active);
    }

    function test_EstablishCorridor_Reverts_OriginNotFound() public {
        _registerTwoAssets();

        InfrastructureAssets.FreightType[] memory types = new InfrastructureAssets.FreightType[](0);
        uint256[] memory transitIds = new uint256[](0);

        vm.prank(operator);
        vm.expectRevert("Origin not found");
        instance.establishCorridor(
            "Bad Corridor",
            "UNKN",
            "DEST",
            transitIds,
            types,
            1000,
            100
        );
    }

    function test_EstablishCorridor_Reverts_DestinationNotFound() public {
        _registerTwoAssets();

        InfrastructureAssets.FreightType[] memory types = new InfrastructureAssets.FreightType[](0);
        uint256[] memory transitIds = new uint256[](0);

        vm.prank(operator);
        vm.expectRevert("Destination not found");
        instance.establishCorridor(
            "Bad Corridor",
            "ORIG",
            "UNKN",
            transitIds,
            types,
            1000,
            100
        );
    }

    // -----------------------------------------------------------------------
    // 4. Freight Dispatch
    // -----------------------------------------------------------------------
    function _setupCorridorAndDispatch()
        internal
        returns (uint256 corridorId, uint256 movementId)
    {
        _registerTwoAssets();

        InfrastructureAssets.FreightType[] memory types = new InfrastructureAssets.FreightType[](1);
        types[0] = InfrastructureAssets.FreightType.Container;
        uint256[] memory transitIds = new uint256[](0);

        vm.prank(operator);
        corridorId = instance.establishCorridor(
            "Atlantic Route",
            "ORIG",
            "DEST",
            transitIds,
            types,
            5000,
            240
        );

        string[] memory checkpoints = new string[](2);
        checkpoints[0] = "Mid-Atlantic Waypoint";
        checkpoints[1] = "UK Customs";

        // Fee = 1_000_000 * 100 / 10000 = 10_000 wei
        uint256 value = 1_000_000;
        uint256 fee = (value * 100) / 10000; // 1% corridor fee

        vm.expectEmit(false, true, true, true);
        emit InfrastructureAssets.FreightDispatched(1, "RIN-001", shipper, corridorId);

        vm.prank(shipper);
        movementId = instance.dispatchFreight{value: fee}(
            corridorId,
            "RIN-001",
            "New York",
            "London",
            InfrastructureAssets.FreightType.Container,
            500,            // volume TEU
            value,
            block.timestamp + 10 days,
            checkpoints
        );
    }

    function test_DispatchFreight() public {
        (, uint256 movementId) = _setupCorridorAndDispatch();

        assertEq(movementId, 1);
        assertEq(instance.movementCounter(), 1);
        assertEq(instance.totalFreightVolume(), 500);
        assertEq(instance.rinToMovementId("RIN-001"), 1);

        (
            ,
            ,
            string memory _rin,
            address _shipper,
            ,
            ,
            ,
            uint256 _volume,
            ,
            ,
            ,
            ,
            ,
            bool _completed
        ) = instance.movements(1);
        assertEq(_rin, "RIN-001");
        assertEq(_shipper, shipper);
        assertEq(_volume, 500);
        assertFalse(_completed);
    }

    function test_DispatchFreight_Reverts_DuplicateRIN() public {
        (uint256 corridorId,) = _setupCorridorAndDispatch();

        string[] memory checkpoints = new string[](1);
        checkpoints[0] = "CP1";
        uint256 value = 1_000_000;
        uint256 fee = (value * 100) / 10000;

        vm.prank(shipper);
        vm.expectRevert("RIN already exists");
        instance.dispatchFreight{value: fee}(
            corridorId,
            "RIN-001", // duplicate
            "New York",
            "London",
            InfrastructureAssets.FreightType.Container,
            100,
            value,
            block.timestamp + 5 days,
            checkpoints
        );
    }

    function test_DispatchFreight_Reverts_InsufficientFee() public {
        _registerTwoAssets();

        InfrastructureAssets.FreightType[] memory types = new InfrastructureAssets.FreightType[](1);
        types[0] = InfrastructureAssets.FreightType.Container;
        uint256[] memory transitIds = new uint256[](0);

        vm.prank(operator);
        uint256 corridorId = instance.establishCorridor(
            "Route",
            "ORIG",
            "DEST",
            transitIds,
            types,
            1000,
            24
        );

        string[] memory checkpoints = new string[](1);
        checkpoints[0] = "CP1";

        vm.prank(shipper);
        vm.expectRevert("Insufficient fee");
        instance.dispatchFreight{value: 0}(
            corridorId,
            "RIN-002",
            "NY",
            "London",
            InfrastructureAssets.FreightType.Container,
            100,
            1_000_000,
            block.timestamp + 5 days,
            checkpoints
        );
    }

    // -----------------------------------------------------------------------
    // 5. Checkpoint Updates
    // -----------------------------------------------------------------------
    function test_UpdateCheckpoint() public {
        (, uint256 movementId) = _setupCorridorAndDispatch();

        vm.expectEmit(true, false, false, true);
        emit InfrastructureAssets.CheckpointReached(movementId, "Mid-Atlantic Waypoint", block.timestamp);

        vm.prank(operator);
        instance.updateCheckpoint(movementId, "Mid-Atlantic Waypoint");

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 _currentCheckpoint,
            bool _completed386
        ) = instance.movements(movementId);
        assertEq(_currentCheckpoint, 1);
        assertFalse(_completed386);
    }

    function test_UpdateCheckpoint_AutoCompletes() public {
        (, uint256 movementId) = _setupCorridorAndDispatch();

        // Move through both checkpoints
        vm.startPrank(operator);
        instance.updateCheckpoint(movementId, "Mid-Atlantic Waypoint");

        vm.expectEmit(true, false, false, false);
        emit InfrastructureAssets.FreightCompleted(movementId, block.timestamp);

        instance.updateCheckpoint(movementId, "UK Customs"); // last checkpoint
        vm.stopPrank();

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 _actualArrival,
            ,
            bool _completed404
        ) = instance.movements(movementId);
        assertTrue(_completed404);
        assertEq(_actualArrival, block.timestamp);
    }

    function test_UpdateCheckpoint_Reverts_AlreadyCompleted() public {
        (, uint256 movementId) = _setupCorridorAndDispatch();

        vm.startPrank(operator);
        instance.updateCheckpoint(movementId, "CP1");
        instance.updateCheckpoint(movementId, "CP2");

        vm.expectRevert("Movement already completed");
        instance.updateCheckpoint(movementId, "CP3");
        vm.stopPrank();
    }

    function test_UpdateCheckpoint_Reverts_NonOperator() public {
        (, uint256 movementId) = _setupCorridorAndDispatch();

        vm.prank(nobody);
        vm.expectRevert();
        instance.updateCheckpoint(movementId, "CP1");
    }

    // -----------------------------------------------------------------------
    // 6. Asset Utilization Update
    // -----------------------------------------------------------------------
    function test_UpdateUtilization() public {
        vm.prank(operator);
        uint256 assetId = instance.registerAsset(
            InfrastructureAssets.AssetType.Seaport,
            "Test Port",
            "TPRT",
            "US",
            "New York",
            "40.7,-74.0",
            1_000_000,
            emptyCorridors,
            false
        );

        vm.prank(operator);
        instance.updateUtilization(assetId, 500_000);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 _currentUtilization,
            ,
            ,
            ,

        ) = instance.assets(assetId);
        assertEq(_currentUtilization, 500_000);
    }

    function test_UpdateUtilization_Reverts_ExceedsCapacity() public {
        vm.prank(operator);
        uint256 assetId = instance.registerAsset(
            InfrastructureAssets.AssetType.Seaport,
            "Test Port",
            "TPRT2",
            "US",
            "New York",
            "40.7,-74.0",
            100,
            emptyCorridors,
            false
        );

        vm.prank(operator);
        vm.expectRevert("Exceeds capacity");
        instance.updateUtilization(assetId, 101);
    }

    // -----------------------------------------------------------------------
    // 7. Port Operations & Investment
    // -----------------------------------------------------------------------
    function test_UpdatePortOperations() public {
        vm.prank(operator);
        uint256 assetId = instance.registerAsset(
            InfrastructureAssets.AssetType.Seaport,
            "Mega Port",
            "MGPT",
            "AE",
            "Dubai",
            "25.2,55.3",
            20_000_000,
            emptyCorridors,
            true
        );

        vm.prank(operator);
        instance.updatePortOperations(assetId, 5, 200, 50_000, 2_000_000, 1_000_000e18);

        (
            ,
            uint256 _vesselsCurrent,
            ,
            uint256 _containersTEU,
            ,
            uint256 _revenue
        ) = instance.operations(assetId);
        assertEq(_vesselsCurrent, 5);
        assertEq(_containersTEU, 50_000);
        assertEq(_revenue, 1_000_000e18);
    }

    function test_UpdatePortOperations_Reverts_NotSeaport() public {
        vm.prank(operator);
        uint256 assetId = instance.registerAsset(
            InfrastructureAssets.AssetType.Airport,
            "Airport",
            "APTR",
            "US",
            "NY",
            "40.6,-73.7",
            3_000_000,
            emptyCorridors,
            false
        );

        vm.prank(operator);
        vm.expectRevert("Not a seaport");
        instance.updatePortOperations(assetId, 0, 0, 0, 0, 0);
    }

    function test_InvestInPort() public {
        vm.prank(operator);
        uint256 assetId = instance.registerAsset(
            InfrastructureAssets.AssetType.Seaport,
            "Investment Port",
            "IVPT",
            "AE",
            "Abu Dhabi",
            "24.4,54.3",
            5_000_000,
            emptyCorridors,
            false
        );

        vm.expectEmit(true, true, false, false);
        emit InfrastructureAssets.PortInvestmentMade(assetId, investor, 5 ether, 0);

        vm.prank(investor);
        instance.investInPort{value: 5 ether}(assetId);

        (
            ,
            ,
            ,
            uint256 _totalShares,
            uint256 _pricePerShare,
            ,

        ) = instance.portFinancials(assetId);
        assertEq(_totalShares, 5 ether);
        assertEq(_pricePerShare, 1 ether);

        (
            ,
            ,
            uint256 _invShares,
            uint256 _investedAmount,
            ,
            ,

        ) = instance.portInvestments(assetId, investor);
        assertEq(_investedAmount, 5 ether);
        assertEq(_invShares, 5 ether);
    }

    function test_InvestInPort_Reverts_NotPort() public {
        vm.prank(operator);
        uint256 assetId = instance.registerAsset(
            InfrastructureAssets.AssetType.Railway,
            "Railway",
            "RWAY",
            "DE",
            "Berlin",
            "52.5,13.4",
            1_000,
            emptyCorridors,
            false
        );

        vm.prank(investor);
        vm.expectRevert("Not a port");
        instance.investInPort{value: 1 ether}(assetId);
    }

    // -----------------------------------------------------------------------
    // 8. Port Revenue & Dividends
    // -----------------------------------------------------------------------
    function test_RecordPortRevenue_AndDistributeDividends() public {
        vm.prank(operator);
        uint256 assetId = instance.registerAsset(
            InfrastructureAssets.AssetType.Seaport,
            "Dividend Port",
            "DVPT",
            "AE",
            "Dubai",
            "25.2,55.3",
            10_000_000,
            emptyCorridors,
            false
        );

        // Invest first
        vm.prank(investor);
        instance.investInPort{value: 10 ether}(assetId);

        // Record revenue with profit (revenue > costs)
        vm.prank(operator);
        instance.recordPortRevenue(assetId, 5 ether, 2 ether);

        vm.expectEmit(true, false, false, false);
        emit InfrastructureAssets.DividendDistributed(assetId, 0);

        vm.prank(operator);
        instance.distributePortDividends(assetId);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 _dividendPerShare
        ) = instance.portFinancials(assetId);
        assertTrue(_dividendPerShare > 0);
    }

    // -----------------------------------------------------------------------
    // 9. Corridor Investment
    // -----------------------------------------------------------------------
    function test_InvestInCorridor() public {
        _registerTwoAssets();

        InfrastructureAssets.FreightType[] memory types = new InfrastructureAssets.FreightType[](1);
        types[0] = InfrastructureAssets.FreightType.Container;
        uint256[] memory transitIds = new uint256[](0);

        vm.prank(operator);
        uint256 corridorId = instance.establishCorridor(
            "Route", "ORIG", "DEST", transitIds, types, 5000, 240
        );

        vm.expectEmit(true, true, false, true);
        emit InfrastructureAssets.CorridorInvestmentMade(corridorId, investor, 3 ether);

        vm.prank(investor);
        instance.investInCorridor{value: 3 ether}(corridorId);

        (,, uint256 pool) = instance.getCorridorProfitability(corridorId);
        assertEq(pool, 3 ether);
    }

    // -----------------------------------------------------------------------
    // 10. getMovementByRIN & getAssetByCode
    // -----------------------------------------------------------------------
    function test_GetMovementByRIN() public {
        (, uint256 movementId) = _setupCorridorAndDispatch();

        (
            uint256 mId,
            uint256 cId,
            address sh,
            string memory origin,
            string memory destination,
            uint256 vol,
            bool completed
        ) = instance.getMovementByRIN("RIN-001");

        assertEq(mId, movementId);
        assertEq(sh, shipper);
        assertEq(origin, "New York");
        assertEq(destination, "London");
        assertEq(vol, 500);
        assertFalse(completed);
    }

    function test_GetMovementByRIN_Reverts_NotFound() public {
        vm.expectRevert("RIN not found");
        instance.getMovementByRIN("INVALID-RIN");
    }

    function test_GetAssetByCode() public {
        vm.prank(operator);
        instance.registerAsset(
            InfrastructureAssets.AssetType.Airport,
            "Test Airport",
            "TAIR",
            "US",
            "Chicago",
            "41.9,-87.6",
            2_000_000,
            emptyCorridors,
            false
        );

        (
            uint256 aId,
            InfrastructureAssets.AssetType aType,
            string memory name,
            string memory country,
            uint256 cap,
            uint256 util,
            InfrastructureAssets.AssetStatus status
        ) = instance.getAssetByCode("TAIR");

        assertEq(aId, 1);
        assertEq(uint8(aType), uint8(InfrastructureAssets.AssetType.Airport));
        assertEq(name, "Test Airport");
        assertEq(country, "US");
        assertEq(cap, 2_000_000);
        assertEq(util, 0);
        assertEq(uint8(status), uint8(InfrastructureAssets.AssetStatus.Active));
    }

    function test_GetAssetByCode_Reverts_NotFound() public {
        vm.expectRevert("Asset not found");
        instance.getAssetByCode("NONE");
    }

    // -----------------------------------------------------------------------
    // 11. Pause / Unpause
    // -----------------------------------------------------------------------
    function test_PauseUnpause() public {
        vm.prank(admin);
        instance.pause();
        assertTrue(instance.paused());

        vm.prank(admin);
        instance.unpause();
        assertFalse(instance.paused());
    }

    function test_Pause_Reverts_NonAdmin() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.pause();
    }
}
