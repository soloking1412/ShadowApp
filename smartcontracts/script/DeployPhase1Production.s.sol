// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/PriceOracleAggregator.sol";
import "../src/UniversalAMM.sol";
import "../src/ForexReservesTracker.sol";

contract DeployPhase1Production is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying Phase 1 Production Contracts...");
        console.log("Deployer:", deployer);
        console.log("Network: Arbitrum Sepolia");

        console.log("\n=== Deploying PriceOracleAggregator ===");
        PriceOracleAggregator oracleImpl = new PriceOracleAggregator();
        bytes memory oracleInitData = abi.encodeWithSelector(
            PriceOracleAggregator.initialize.selector,
            deployer
        );
        ERC1967Proxy oracleProxy = new ERC1967Proxy(address(oracleImpl), oracleInitData);
        console.log("PriceOracleAggregator Proxy:", address(oracleProxy));
        console.log("PriceOracleAggregator Implementation:", address(oracleImpl));

        console.log("\n=== Deploying UniversalAMM ===");
        UniversalAMM ammImpl = new UniversalAMM();
        bytes memory ammInitData = abi.encodeWithSelector(
            UniversalAMM.initialize.selector,
            deployer
        );
        ERC1967Proxy ammProxy = new ERC1967Proxy(address(ammImpl), ammInitData);
        console.log("UniversalAMM Proxy:", address(ammProxy));
        console.log("UniversalAMM Implementation:", address(ammImpl));

        console.log("\n=== Upgrading ForexReservesTracker (61 currencies) ===");
        ForexReservesTracker forexImpl = new ForexReservesTracker();
        console.log("ForexReservesTracker Implementation:", address(forexImpl));

        vm.stopBroadcast();

        console.log("\n=== Phase 1 Production Deployment Summary ===");
        console.log("\nAdd these to frontend/.env.local:");
        console.log("NEXT_PUBLIC_PRICE_ORACLE_ADDRESS=", address(oracleProxy));
        console.log("NEXT_PUBLIC_UNIVERSAL_AMM_ADDRESS=", address(ammProxy));

        console.log("\n=== Implementation Addresses for Upgrades ===");
        console.log("ForexReservesTracker_Implementation=", address(forexImpl));

        console.log("\n=== Next Steps ===");
        console.log("1. Add new contract addresses to frontend/.env.local");
        console.log("2. Upgrade ForexReservesTracker proxy using implementation address");
        console.log("3. Set AMM address in ForexReservesTracker: setAMMAddress(", address(ammProxy), ")");
        console.log("4. Register initial price feeds in PriceOracleAggregator");
        console.log("5. Create initial liquidity pools in UniversalAMM");
        console.log("6. Test all functionality on testnet");

        console.log("\n=== Estimated Gas Costs ===");
        console.log("PriceOracleAggregator: ~0.001 ETH");
        console.log("UniversalAMM: ~0.002 ETH");
        console.log("ForexReservesTracker: ~0.0015 ETH");
        console.log("Total: ~0.0045 ETH (~$11.25)");
    }
}
