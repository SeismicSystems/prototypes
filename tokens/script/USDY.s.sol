// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {USDY} from "../src/USDY.sol";

contract USDYScript is Script {
    USDY public usdy;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVKEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy USDY with admin address
        usdy = new USDY(admin);
        
        // Grant initial roles if needed
        address minter = vm.envAddress("MINTER_ADDRESS");
        address burner = vm.envAddress("BURNER_ADDRESS");
        address oracle = vm.envAddress("ORACLE_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        
        usdy.grantRole(usdy.MINTER_ROLE(), minter);
        usdy.grantRole(usdy.BURNER_ROLE(), burner);
        usdy.grantRole(usdy.ORACLE_ROLE(), oracle);
        usdy.grantRole(usdy.PAUSE_ROLE(), pauser);
        
        vm.stopBroadcast();

        console.log("USDY deployed to:", address(usdy));
        console.log("Admin:", admin);
        console.log("Minter:", minter);
        console.log("Burner:", burner);
        console.log("Oracle:", oracle);
        console.log("Pauser:", pauser);
    }
}
