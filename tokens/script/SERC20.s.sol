// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SERC20} from "../src/SERC20.sol";

// Create concrete implementation of SERC20
contract ConcreteERC20 is SERC20 {
    constructor(string memory name, string memory symbol) 
        SERC20(name, symbol) 
    {}
}

contract SERC20Script is Script {
    ConcreteERC20 public serc20;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVKEY");

        vm.startBroadcast(deployerPrivateKey);
        serc20 = new ConcreteERC20("Seismic ERC20", "SERC");
        vm.stopBroadcast();
    }
}
