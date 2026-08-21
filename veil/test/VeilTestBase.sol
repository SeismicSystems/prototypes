// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Veil} from "../src/Veil.sol";
import {ISRC20} from "../src/ISRC20.sol";
import {TestToken} from "./TestToken.sol";

/// @title VeilTestBase
/// @notice Shared setup and helpers for the Veil test suite
abstract contract VeilTestBase is Test {
    address internal constant RNG_PRECOMPILE = address(0x64);

    uint256 internal constant TICKET_PRICE = 10e18;
    uint256 internal constant DURATION = 1 days;

    TestToken internal token;
    Veil internal veil;

    function setUp() public virtual {
        token = new TestToken();
        veil = new Veil(ISRC20(address(token)), TICKET_PRICE, DURATION);
    }

    /// @dev Mocks the RNG builtin to return a fixed 32 byte value on its next call
    function _mockRng(uint256 value) internal {
        vm.mockCall(RNG_PRECOMPILE, abi.encodePacked(uint32(32)), abi.encodePacked(bytes32(value)));
    }

    /// @dev Funds an address with enough token to buy numTickets tickets and approves Veil
    function _fundAndApprove(address entrant, uint256 numTickets) internal {
        token.mint(entrant, suint256(TICKET_PRICE * numTickets));
        vm.prank(entrant);
        token.approve(address(veil), suint256(TICKET_PRICE * numTickets));
    }

    /// @dev Funds, approves, and enters on behalf of an EOA-style test address
    function _enter(address entrant, uint256 numTickets) internal {
        _fundAndApprove(entrant, numTickets);
        vm.prank(entrant);
        veil.enter(suint256(numTickets));
    }

    function _balanceOf(address account) internal returns (uint256) {
        vm.prank(account);
        return token.balanceOf();
    }

    function _closeEntries() internal {
        vm.warp(block.timestamp + DURATION);
    }

    function _drawWithRandomness(uint256 rngValue) internal {
        _mockRng(rngValue);
        veil.draw();
    }
}
