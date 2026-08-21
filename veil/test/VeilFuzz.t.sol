// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {VeilTestBase} from "./VeilTestBase.sol";

contract VeilFuzzTest is VeilTestBase {
    address internal alice = makeAddr("fuzzAlice");
    address internal bob = makeAddr("fuzzBob");
    address internal carol = makeAddr("fuzzCarol");
    address internal dave = makeAddr("fuzzDave");

    /// @dev For an arbitrary set of ticket counts and an arbitrary raw randomness value, exactly
    /// one of the four entrants can claim, it is always the entrant whose cumulative range
    /// covers the resulting winning ticket, a losing claim always reverts, and the winner is
    /// paid exactly the full pot exactly once.
    function testFuzz_ExactlyOneEntrantCanClaim(
        uint8 aTickets,
        uint8 bTickets,
        uint8 cTickets,
        uint8 dTickets,
        uint256 rawRandomness
    ) public {
        uint256 a = bound(aTickets, 1, 50);
        uint256 b = bound(bTickets, 1, 50);
        uint256 c = bound(cTickets, 1, 50);
        uint256 d = bound(dTickets, 1, 50);

        _enter(alice, a);
        _enter(bob, b);
        _enter(carol, c);
        _enter(dave, d);

        uint256 total = a + b + c + d;
        _closeEntries();
        _drawWithRandomness(rawRandomness);
        vm.roll(block.number + 1);

        uint256 winningTicket = rawRandomness % total;

        address[4] memory entrants = [alice, bob, carol, dave];
        uint256[4] memory counts = [a, b, c, d];

        address expectedWinner;
        uint256 cumulative;
        for (uint256 i = 0; i < 4; i++) {
            if (winningTicket >= cumulative && winningTicket < cumulative + counts[i]) {
                expectedWinner = entrants[i];
            }
            cumulative += counts[i];
        }

        uint256 pot = TICKET_PRICE * total;
        uint256 successes = 0;

        for (uint256 i = 0; i < 4; i++) {
            vm.prank(entrants[i]);
            try veil.claim() {
                successes++;
                assertEq(entrants[i], expectedWinner, "only the range owner covering the winning ticket may claim");
                assertEq(_balanceOf(entrants[i]), pot, "the winner must receive the full pot exactly once");
            } catch {
                assertTrue(entrants[i] != expectedWinner, "the true winner must never have its claim revert");
            }
        }

        assertEq(successes, 1, "exactly one entrant must be able to claim");
    }
}
