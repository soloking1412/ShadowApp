// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/OICDTreasury.sol";
import "../src/TwoDIBondTracker.sol";
import "../src/DarkPool.sol";
import "../src/FractionalReserveBanking.sol";
import "../src/ForexReservesTracker.sol";
import "../src/SovereignInvestmentDAO.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("\n=== ARBITRUM SEPOLIA DEPLOYMENT ===");
        console.log("Deployer address:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("\n");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy OICDTreasury
        console.log("1. Deploying OICDTreasury...");
        OICDTreasury treasuryImpl = new OICDTreasury();
        bytes memory treasuryData = abi.encodeWithSelector(
            OICDTreasury.initialize.selector,
            "https://shadowdapp.com/metadata/{id}",
            deployer,
            250_000_000_000 * 1e18
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImpl), treasuryData);
        console.log("   Implementation:", address(treasuryImpl));
        console.log("   Proxy:", address(treasuryProxy));

        // 2. Deploy TwoDIBondTracker
        console.log("2. Deploying TwoDIBondTracker...");
        TwoDIBondTracker bondsImpl = new TwoDIBondTracker();
        bytes memory bondsData = abi.encodeWithSelector(
            TwoDIBondTracker.initialize.selector,
            deployer,
            "https://shadowdapp.com/bonds/{id}"
        );
        ERC1967Proxy bondsProxy = new ERC1967Proxy(address(bondsImpl), bondsData);
        console.log("   Implementation:", address(bondsImpl));
        console.log("   Proxy:", address(bondsProxy));

        // 3. Deploy DarkPool
        console.log("3. Deploying DarkPool...");
        DarkPool darkPoolImpl = new DarkPool();
        bytes memory darkPoolData = abi.encodeWithSelector(
            DarkPool.initialize.selector,
            deployer,
            100_000 * 1e18,
            10_000_000_000 * 1e18,
            30,
            deployer
        );
        ERC1967Proxy darkPoolProxy = new ERC1967Proxy(address(darkPoolImpl), darkPoolData);
        console.log("   Implementation:", address(darkPoolImpl));
        console.log("   Proxy:", address(darkPoolProxy));

        // 4. Deploy FractionalReserveBanking
        console.log("4. Deploying FractionalReserveBanking...");
        FractionalReserveBanking bankingImpl = new FractionalReserveBanking();
        bytes memory bankingData = abi.encodeWithSelector(
            FractionalReserveBanking.initialize.selector,
            deployer,
            2000
        );
        ERC1967Proxy bankingProxy = new ERC1967Proxy(address(bankingImpl), bankingData);
        console.log("   Implementation:", address(bankingImpl));
        console.log("   Proxy:", address(bankingProxy));

        // 5. Deploy ForexReservesTracker
        console.log("5. Deploying ForexReservesTracker...");
        ForexReservesTracker forexImpl = new ForexReservesTracker();
        bytes memory forexData = abi.encodeWithSelector(
            ForexReservesTracker.initialize.selector,
            deployer
        );
        ERC1967Proxy forexProxy = new ERC1967Proxy(address(forexImpl), forexData);
        console.log("   Implementation:", address(forexImpl));
        console.log("   Proxy:", address(forexProxy));

        // 6. Deploy SovereignInvestmentDAO
        console.log("6. Deploying SovereignInvestmentDAO...");
        SovereignInvestmentDAO daoImpl = new SovereignInvestmentDAO();
        bytes memory daoData = abi.encodeWithSelector(
            SovereignInvestmentDAO.initialize.selector,
            deployer,
            7 days,
            2 days,
            55
        );
        ERC1967Proxy daoProxy = new ERC1967Proxy(address(daoImpl), daoData);
        console.log("   Implementation:", address(daoImpl));
        console.log("   Proxy:", address(daoProxy));

        vm.stopBroadcast();

        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("\nProxy Addresses (use these in frontend):");
        console.log("NEXT_PUBLIC_OICD_TREASURY_ADDRESS=", address(treasuryProxy));
        console.log("NEXT_PUBLIC_TWODI_BOND_TRACKER_ADDRESS=", address(bondsProxy));
        console.log("NEXT_PUBLIC_DARK_POOL_ADDRESS=", address(darkPoolProxy));
        console.log("NEXT_PUBLIC_FRACTIONAL_RESERVE_ADDRESS=", address(bankingProxy));
        console.log("NEXT_PUBLIC_FOREX_RESERVES_ADDRESS=", address(forexProxy));
        console.log("NEXT_PUBLIC_SOVEREIGN_DAO_ADDRESS=", address(daoProxy));
        console.log("\nVerify on Arbiscan:");
        console.log("https://sepolia.arbiscan.io/address/", address(treasuryProxy));
    }
}
