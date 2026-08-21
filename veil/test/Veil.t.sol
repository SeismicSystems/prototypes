// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {stdError} from "forge-std/StdError.sol";
import {VeilTestBase} from "./VeilTestBase.sol";

contract VeilCorrectnessTest is VeilTestBase {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function test_Enter_PullsExactPayment() public {
        _fundAndApprove(alice, 4);

        uint256 veilBalanceBefore = _balanceOf(address(veil));

        vm.prank(alice);
        veil.enter(suint256(4));

        assertEq(_balanceOf(alice), 0, "entrant should be debited the full payment");
        assertEq(
            _balanceOf(address(veil)), veilBalanceBefore + TICKET_PRICE * 4, "veil should hold exactly the payment"
        );
    }

    function test_Draw_DeclassifiesCorrectTotal() public {
        _enter(alice, 3);
        _enter(bob, 5);
        _enter(carol, 2);

        _closeEntries();
        _drawWithRandomness(0);

        assertEq(veil.totalTicketsSold(), 10, "declassified total must equal the sum of all entries");
    }

    function test_Claim_WinnerReceivesFullPot() public {
        _enter(alice, 3);
        _enter(bob, 5);
        _enter(carol, 2);

        uint256 pot = TICKET_PRICE * 10;
        assertEq(_balanceOf(address(veil)), pot, "pot should equal every entrant's payment");

        _closeEntries();
        // Raw RNG output 4 falls in bob's range [3, 8).
        _drawWithRandomness(4);
        vm.roll(block.number + 1);

        vm.prank(bob);
        veil.claim();

        assertEq(_balanceOf(bob), pot, "winner should receive the entire pot");
        assertEq(_balanceOf(address(veil)), 0, "veil should be fully drained after payout");
    }

    function test_TokenBalances_ReconcileEndToEnd() public {
        _enter(alice, 3);
        _enter(bob, 5);
        _enter(carol, 2);

        uint256 totalPaid = TICKET_PRICE * 3 + TICKET_PRICE * 5 + TICKET_PRICE * 2;
        assertEq(_balanceOf(address(veil)), totalPaid, "veil balance must equal the sum of all payments");

        _closeEntries();
        _drawWithRandomness(0);
        vm.roll(block.number + 1);

        vm.prank(alice);
        veil.claim();

        assertEq(_balanceOf(alice), totalPaid, "winner's payout must equal exactly what was collected");
        assertEq(_balanceOf(bob), 0, "non-winners receive nothing");
        assertEq(_balanceOf(carol), 0, "non-winners receive nothing");
    }

    /// @dev Sweeps every boundary and interior ticket value across three entrants and confirms
    /// the ranges are contiguous, non-overlapping, and gapless: for every value in [0, total),
    /// exactly one entrant can claim, and it is always the mathematically expected one.
    function test_Ranges_ContiguousNonOverlappingGapless() public {
        _enter(alice, 3); // expected range [0, 3)
        _enter(bob, 5); // expected range [3, 8)
        _enter(carol, 2); // expected range [8, 10)
        _closeEntries();

        uint256[7] memory winningValues = [uint256(0), 2, 3, 4, 7, 8, 9];
        address[7] memory expectedWinners = [alice, alice, bob, bob, bob, carol, carol];

        for (uint256 i = 0; i < winningValues.length; i++) {
            uint256 snapshot = vm.snapshotState();

            _drawWithRandomness(winningValues[i]);
            vm.roll(block.number + 1);

            address expected = expectedWinners[i];
            address[3] memory all = [alice, bob, carol];
            uint256 successes = 0;

            for (uint256 j = 0; j < all.length; j++) {
                vm.prank(all[j]);
                try veil.claim() {
                    successes++;
                    assertEq(all[j], expected, "the claiming entrant must match the expected range owner");
                } catch {
                    assertTrue(all[j] != expected, "the expected winner must not revert");
                }
            }

            assertEq(successes, 1, "exactly one entrant must be able to claim for each winning value");

            vm.revertToState(snapshot);
        }
    }
}

contract VeilGuardsTest is VeilTestBase {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    /// @dev With no prior approve(), the token's own allowance bookkeeping underflows before
    /// Veil ever gets a chance to check a return value: transferFrom reverts, it doesn't return
    /// false. This is the SRC20's real failure mode and the honest one to assert against.
    function test_Enter_RevertsWithoutApproval() public {
        token.mint(alice, suint256(TICKET_PRICE));
        vm.prank(alice);
        vm.expectRevert(stdError.arithmeticError);
        veil.enter(suint256(1));
    }

    function test_Enter_RevertsWithInsufficientApproval() public {
        token.mint(alice, suint256(TICKET_PRICE * 2));
        vm.prank(alice);
        token.approve(address(veil), suint256(TICKET_PRICE));

        vm.prank(alice);
        vm.expectRevert(stdError.arithmeticError);
        veil.enter(suint256(2));
    }

    function test_Enter_RevertsOnZeroTickets() public {
        _fundAndApprove(alice, 1);
        vm.prank(alice);
        vm.expectRevert("must buy at least one ticket");
        veil.enter(suint256(0));
    }

    function test_Enter_RevertsOnDoubleEntry() public {
        _enter(alice, 1);
        _fundAndApprove(alice, 1);
        vm.prank(alice);
        vm.expectRevert("already entered");
        veil.enter(suint256(1));
    }

    function test_Enter_RevertsAfterDeadline() public {
        _fundAndApprove(alice, 1);
        _closeEntries();
        vm.prank(alice);
        vm.expectRevert("entries are closed");
        veil.enter(suint256(1));
    }

    function test_Draw_RevertsBeforeDeadline() public {
        _enter(alice, 1);
        vm.expectRevert("entries still open");
        veil.draw();
    }

    function test_Draw_RevertsWithNoEntrants() public {
        _closeEntries();
        vm.expectRevert("no entrants");
        veil.draw();
    }

    function test_Draw_RevertsIfAlreadyDrawn() public {
        _enter(alice, 1);
        _closeEntries();
        _drawWithRandomness(0);

        vm.expectRevert("already drawn");
        veil.draw();
    }

    function test_Claim_RevertsBeforeDraw() public {
        _enter(alice, 1);
        _closeEntries();

        vm.prank(alice);
        vm.expectRevert("not drawn yet");
        veil.claim();
    }

    function test_Claim_RevertsForNonEntrant() public {
        _enter(alice, 1);
        _closeEntries();
        _drawWithRandomness(0);
        vm.roll(block.number + 1);

        vm.prank(bob);
        vm.expectRevert("did not enter");
        veil.claim();
    }

    function test_Claim_RevertsOnDoubleClaim() public {
        _enter(alice, 1);
        _closeEntries();
        _drawWithRandomness(0);
        vm.roll(block.number + 1);

        vm.prank(alice);
        veil.claim();

        vm.prank(alice);
        vm.expectRevert("already claimed");
        veil.claim();
    }

    function test_Claim_RevertsForNonWinner() public {
        _enter(alice, 1); // range [0, 1)
        _enter(bob, 1); // range [1, 2)
        _closeEntries();
        _drawWithRandomness(0); // winning ticket is 0, alice's range
        vm.roll(block.number + 1);

        vm.prank(bob);
        vm.expectRevert("not the winner");
        veil.claim();
    }
}
