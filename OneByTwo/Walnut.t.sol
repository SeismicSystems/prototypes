// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Walnut} from "../src/Walnut.sol";

contract WalnutTest is Test {
    Walnut public walnut;

    function setUp() public {
        walnut = new Walnut(2, suint256(0));

        saddress a = saddress(0x123);
        console.log(address(a));
    }

    function test_Cracked() public {
        walnut.shake();
        walnut.hit();
        walnut.hit();
        assertEq(walnut.look(), 1);
    }

    function testFail_EarlyLook() public {
        walnut.hit();
        walnut.shake();
        walnut.look();
    }

    function test_ManyActions() public {
        uint256 shakes = 0;
        for (uint256 i = 0; i < 50; i++) {
            if (i % 3 == 0) {
                walnut.hit();
            } else {
                walnut.shake();
                shakes++;
            }
        }
        assertEq(walnut.look(), shakes);
    }
}
