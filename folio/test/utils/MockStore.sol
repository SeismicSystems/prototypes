// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

import {IStoreFront} from "../../src/IStoreFront.sol";
import {Test, console} from "forge-std/Test.sol";

contract MockStore is IStoreFront {

    // fulfilling the IStoreFront interface
    function purchase(suint prodId) external payable override {
        console.log("entered purchase");
    }

    // receiving external payments
    // this is neeeded for testing if a business can recieve a payout for winning the competition
    receive() external payable {
        console.log("received");
    }

}
