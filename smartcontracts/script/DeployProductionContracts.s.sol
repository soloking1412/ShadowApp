// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/TwoDIBondTracker.sol";
import "../src/DarkPool.sol";
import "../src/FractionalReserveBanking.sol";
import "../src/ObsidianCapital.sol";
import "../src/InfrastructureAssets.sol";
import "../src/OGRBlacklist.sol";
import "../src/InviteManager.sol";

contract DeployProductionContracts is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying production-ready contracts...");
        console.log("Deployer:", deployer);

        console.log("\n=== Deploying OGR Blacklist ===");
        OGRBlacklist blacklistImpl = new OGRBlacklist();
        bytes memory blacklistInitData = abi.encodeWithSelector(
            OGRBlacklist.initialize.selector,
            deployer
        );
        ERC1967Proxy blacklistProxy = new ERC1967Proxy(address(blacklistImpl), blacklistInitData);
        console.log("OGRBlacklist Proxy:", address(blacklistProxy));

        console.log("\n=== Deploying Invite Manager ===");
        InviteManager inviteImpl = new InviteManager();
        bytes memory inviteInitData = abi.encodeWithSelector(
            InviteManager.initialize.selector,
            deployer
        );
        ERC1967Proxy inviteProxy = new ERC1967Proxy(address(inviteImpl), inviteInitData);
        console.log("InviteManager Proxy:", address(inviteProxy));

        console.log("\n=== Upgrading TwoDIBondTracker (Fixed) ===");
        TwoDIBondTracker bondImpl = new TwoDIBondTracker();
        console.log("TwoDIBondTracker Implementation:", address(bondImpl));

        console.log("\n=== Upgrading DarkPool (Fixed Transfers) ===");
        DarkPool darkPoolImpl = new DarkPool();
        console.log("DarkPool Implementation:", address(darkPoolImpl));

        console.log("\n=== Upgrading FractionalReserveBanking (Fixed Transfers) ===");
        FractionalReserveBanking bankingImpl = new FractionalReserveBanking();
        console.log("FractionalReserveBanking Implementation:", address(bankingImpl));

        console.log("\n=== Upgrading ObsidianCapital (Fixed Transfers) ===");
        ObsidianCapital capitalImpl = new ObsidianCapital();
        console.log("ObsidianCapital Implementation:", address(capitalImpl));

        console.log("\n=== Upgrading InfrastructureAssets (Added Profit Distribution) ===");
        InfrastructureAssets infraImpl = new InfrastructureAssets();
        console.log("InfrastructureAssets Implementation:", address(infraImpl));

        vm.stopBroadcast();

        console.log("\n=== Production Deployment Summary ===");
        console.log("NEXT_PUBLIC_OGR_BLACKLIST_ADDRESS=", address(blacklistProxy));
        console.log("NEXT_PUBLIC_INVITE_MANAGER_ADDRESS=", address(inviteProxy));
        console.log("\n=== Implementation Addresses for Upgrades ===");
        console.log("TwoDIBondTracker_Implementation=", address(bondImpl));
        console.log("DarkPool_Implementation=", address(darkPoolImpl));
        console.log("FractionalReserveBanking_Implementation=", address(bankingImpl));
        console.log("ObsidianCapital_Implementation=", address(capitalImpl));
        console.log("InfrastructureAssets_Implementation=", address(infraImpl));

        console.log("\n=== Next Steps ===");
        console.log("1. Add new addresses to frontend/.env.local");
        console.log("2. Upgrade existing proxies using implementation addresses");
        console.log("3. Test all functionality on testnet");
        console.log("4. Run security audit");
    }
}
