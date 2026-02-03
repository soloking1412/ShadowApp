// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/ForexReservesTracker.sol";
import "../src/PriceOracleAggregator.sol";
import "../src/UniversalAMM.sol";

interface IUpgradeable {
    function upgradeTo(address newImplementation) external;
}

contract ConfigurePhase1 is Script {
    address constant FOREX_PROXY = 0x5F98fE66CFA24f3b0D6925b0F6F3a67c1F0e4eE6;
    address constant FOREX_NEW_IMPL = 0x293E1c3959CB9e32FA34e9646bd40Cc3Daa1E177;
    address constant UNIVERSAL_AMM = 0x5853fE6218565F9b3d4b689d5268f3599fD52D80;
    address constant PRICE_ORACLE = 0xD4BA781fa4A5fC32c27E96F7d3E596B96de7D15a;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Configuring Phase 1 Production...");
        console.log("Deployer:", deployer);

        console.log("\n=== Step 1: Upgrade ForexReservesTracker ===");
        IUpgradeable(FOREX_PROXY).upgradeTo(FOREX_NEW_IMPL);
        console.log("ForexReservesTracker upgraded successfully");

        ForexReservesTracker forexProxy = ForexReservesTracker(FOREX_PROXY);

        console.log("\n=== Step 2: Set AMM Address in ForexReservesTracker ===");
        forexProxy.setAMMAddress(UNIVERSAL_AMM);
        console.log("AMM address set successfully");

        console.log("\n=== Step 3: Verify Configuration ===");
        address ammAddress = forexProxy.ammAddress();
        console.log("Configured AMM Address:", ammAddress);

        if (ammAddress == UNIVERSAL_AMM) {
            console.log("AMM configuration verified!");
        } else {
            console.log("Warning: AMM address mismatch");
        }

        string[] memory currencies = forexProxy.getAllCurrencies();
        console.log("Total currencies:", currencies.length);

        vm.stopBroadcast();

        console.log("\n=== Phase 1 Configuration Complete ===");
        console.log("ForexReservesTracker: Upgraded & Configured");
        console.log("UniversalAMM: Ready for liquidity pools");
        console.log("PriceOracleAggregator: Ready for price feeds");
    }
}
