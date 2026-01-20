// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/GovernmentSecuritiesSettlement.sol";
import "../src/DigitalTradeBlocks.sol";
import "../src/OZFParliament.sol";
import "../src/ObsidianCapital.sol";
import "../src/ArmsTradeCompliance.sol";
import "../src/InfrastructureAssets.sol";
import "../src/PrimeBrokerage.sol";
import "../src/LiquidityAsAService.sol";
import "../src/SpecialEconomicZone.sol";

contract DeployNewContracts is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get already deployed addresses if they exist
        address darkPoolAddress = vm.envOr("NEXT_PUBLIC_DARK_POOL_ADDRESS", address(0));
        address cexAddress = vm.envOr("NEXT_PUBLIC_CEX_ADDRESS", address(0));

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying all new contracts...");
        console.log("Deployer:", deployer);

        // 1. Deploy GovernmentSecuritiesSettlement
        GovernmentSecuritiesSettlement govSecImpl = new GovernmentSecuritiesSettlement();
        bytes memory govSecInitData = abi.encodeWithSelector(
            GovernmentSecuritiesSettlement.initialize.selector,
            deployer
        );
        ERC1967Proxy govSecProxy = new ERC1967Proxy(address(govSecImpl), govSecInitData);
        console.log("GovernmentSecuritiesSettlement Proxy:", address(govSecProxy));

        // 2. Deploy DigitalTradeBlocks
        DigitalTradeBlocks tradeBlocksImpl = new DigitalTradeBlocks();
        bytes memory tradeBlocksInitData = abi.encodeWithSelector(
            DigitalTradeBlocks.initialize.selector,
            "Digital Trade Blocks",
            "DTB",
            deployer
        );
        ERC1967Proxy tradeBlocksProxy = new ERC1967Proxy(address(tradeBlocksImpl), tradeBlocksInitData);
        console.log("DigitalTradeBlocks Proxy:", address(tradeBlocksProxy));

        // 3. Deploy OZFParliament
        OZFParliament parliamentImpl = new OZFParliament();
        bytes memory parliamentInitData = abi.encodeWithSelector(
            OZFParliament.initialize.selector,
            deployer, // chairman
            deployer, // prime minister
            deployer  // treasury governor
        );
        ERC1967Proxy parliamentProxy = new ERC1967Proxy(address(parliamentImpl), parliamentInitData);
        console.log("OZFParliament Proxy:", address(parliamentProxy));

        // 4. Deploy ObsidianCapital
        ObsidianCapital obsidianImpl = new ObsidianCapital();
        bytes memory obsidianInitData = abi.encodeWithSelector(
            ObsidianCapital.initialize.selector,
            deployer,
            darkPoolAddress != address(0) ? darkPoolAddress : deployer,
            cexAddress != address(0) ? cexAddress : deployer,
            200,  // 2% management fee
            2000  // 20% performance fee
        );
        ERC1967Proxy obsidianProxy = new ERC1967Proxy(address(obsidianImpl), obsidianInitData);
        console.log("ObsidianCapital Proxy:", address(obsidianProxy));

        // 5. Deploy ArmsTradeCompliance
        ArmsTradeCompliance armsTradeImpl = new ArmsTradeCompliance();
        bytes memory armsTradeInitData = abi.encodeWithSelector(
            ArmsTradeCompliance.initialize.selector,
            deployer
        );
        ERC1967Proxy armsTradeProxy = new ERC1967Proxy(address(armsTradeImpl), armsTradeInitData);
        console.log("ArmsTradeCompliance Proxy:", address(armsTradeProxy));

        // 6. Deploy InfrastructureAssets
        InfrastructureAssets infraImpl = new InfrastructureAssets();
        bytes memory infraInitData = abi.encodeWithSelector(
            InfrastructureAssets.initialize.selector,
            deployer
        );
        ERC1967Proxy infraProxy = new ERC1967Proxy(address(infraImpl), infraInitData);
        console.log("InfrastructureAssets Proxy:", address(infraProxy));

        // 7. Deploy PrimeBrokerage
        PrimeBrokerage primeImpl = new PrimeBrokerage();
        bytes memory primeInitData = abi.encodeWithSelector(
            PrimeBrokerage.initialize.selector,
            deployer
        );
        ERC1967Proxy primeProxy = new ERC1967Proxy(address(primeImpl), primeInitData);
        console.log("PrimeBrokerage Proxy:", address(primeProxy));

        // 8. Deploy LiquidityAsAService
        LiquidityAsAService laasImpl = new LiquidityAsAService();
        bytes memory laasInitData = abi.encodeWithSelector(
            LiquidityAsAService.initialize.selector,
            deployer
        );
        ERC1967Proxy laasProxy = new ERC1967Proxy(address(laasImpl), laasInitData);
        console.log("LiquidityAsAService Proxy:", address(laasProxy));

        // 9. Deploy SpecialEconomicZone
        SpecialEconomicZone sezImpl = new SpecialEconomicZone();
        bytes memory sezInitData = abi.encodeWithSelector(
            SpecialEconomicZone.initialize.selector,
            deployer
        );
        ERC1967Proxy sezProxy = new ERC1967Proxy(address(sezImpl), sezInitData);
        console.log("SpecialEconomicZone Proxy:", address(sezProxy));

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("NEXT_PUBLIC_GOV_SECURITIES_ADDRESS=", address(govSecProxy));
        console.log("NEXT_PUBLIC_DIGITAL_TRADE_BLOCKS_ADDRESS=", address(tradeBlocksProxy));
        console.log("NEXT_PUBLIC_OZF_PARLIAMENT_ADDRESS=", address(parliamentProxy));
        console.log("NEXT_PUBLIC_OBSIDIAN_CAPITAL_ADDRESS=", address(obsidianProxy));
        console.log("NEXT_PUBLIC_ARMS_TRADE_ADDRESS=", address(armsTradeProxy));
        console.log("NEXT_PUBLIC_INFRASTRUCTURE_ASSETS_ADDRESS=", address(infraProxy));
        console.log("NEXT_PUBLIC_PRIME_BROKERAGE_ADDRESS=", address(primeProxy));
        console.log("NEXT_PUBLIC_LIQUIDITY_SERVICE_ADDRESS=", address(laasProxy));
        console.log("NEXT_PUBLIC_SEZ_ADDRESS=", address(sezProxy));
    }
}
