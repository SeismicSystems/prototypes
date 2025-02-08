// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SRC20} from "../src/SRC20.sol";

// Create concrete implementation of SRC20
contract ConcreteERC20 is SRC20 {
    constructor(string memory name, string memory symbol) 
        SRC20(name, symbol) 
    {}
}

contract SRC20Script is Script {
    ConcreteERC20 public src20;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVKEY");

        vm.startBroadcast(deployerPrivateKey);
        src20 = new ConcreteERC20("Seismic ERC20", "SERC");
        vm.stopBroadcast();
    }
}
