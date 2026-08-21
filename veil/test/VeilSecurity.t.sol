// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";
import {VeilTestBase} from "./VeilTestBase.sol";
import {Veil} from "../src/Veil.sol";
import {ISRC20} from "../src/ISRC20.sol";

/// @dev Enters Veil on its own behalf and bundles draw() with claim() in a single call, so a
/// revert anywhere in that call undoes both. This is the atomic grinding pattern the block gate
/// on claim() is meant to defeat.
contract BundlingAttacker {
    Veil internal immutable veil;
    ISRC20 internal immutable token;

    constructor(Veil _veil, ISRC20 _token) {
        veil = _veil;
        token = _token;
    }

    function enterWithTickets(uint256 numTickets, uint256 payment) external {
        token.approve(address(veil), suint256(payment));
        veil.enter(suint256(numTickets));
    }

    function attempt() external {
        veil.draw();
        veil.claim();
    }
}

/// @dev A token that is also its own entrant. When Veil pays out through transfer(), it calls
/// back into claim() before returning, simulating a nonstandard token with a transfer hook.
/// The canonical SRC20 shape has no such hook, transfer() never calls the recipient, so this
/// is not exploitable against the token Veil actually ships against. It proves that Veil's own
/// ordering in claim() (marking the caller claimed before the external transfer call) would
/// still hold the line if it were ever pointed at a token that did call back.
contract ReentrantToken is ISRC20 {
    Veil internal veil;
    mapping(address => suint256) private balance;

    bool public reentryAttempted;
    bool public reentrySucceeded;

    function setVeil(Veil _veil) external {
        veil = _veil;
    }

    function mint(address to, suint256 amount) external {
        unchecked {
            balance[to] += amount;
        }
    }

    function enterRaffle(suint256 numTickets, suint256 payment) external {
        this.approve(address(veil), payment);
        veil.enter(numTickets);
    }

    function name() external pure returns (string memory) {
        return "Reentrant Token";
    }

    function symbol() external pure returns (string memory) {
        return "RE";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function balanceOf() external view returns (uint256) {
        return uint256(balance[msg.sender]);
    }

    function approve(address, suint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address from, address to, suint256 amount) external returns (bool) {
        unchecked {
            balance[from] -= amount;
            balance[to] += amount;
        }
        return true;
    }

    function transfer(address to, suint256 amount) external returns (bool) {
        reentryAttempted = true;
        try veil.claim() {
            reentrySucceeded = true;
        } catch {
            reentrySucceeded = false;
        }

        unchecked {
            balance[msg.sender] -= amount;
            balance[to] += amount;
        }
        return true;
    }
}

contract VeilSecurityTest is VeilTestBase {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function test_Claim_RevertsInSameBlockAsDraw() public {
        _enter(alice, 1);
        _closeEntries();
        _drawWithRandomness(0);

        vm.prank(alice);
        vm.expectRevert("draw not finalized yet");
        veil.claim();
    }

    /// @dev Reproduces the atomic bundling grind directly: the attacker holds the exact ticket
    /// range that the mocked randomness would make the winner, and still cannot collect,
    /// because claim() cannot succeed in the same block as draw() no matter how the call is
    /// composed. The same attacker succeeding afterward through the honest, unbundled path
    /// proves this is the bundling attack failing, not the raffle being broken.
    function test_BundledDrawAndClaim_CannotForceAWin() public {
        BundlingAttacker attacker = new BundlingAttacker(veil, ISRC20(address(token)));
        token.mint(address(attacker), suint256(TICKET_PRICE));
        attacker.enterWithTickets(1, TICKET_PRICE); // attacker's range is [0, 1)

        _closeEntries();

        for (uint256 i = 0; i < 5; i++) {
            _mockRng(0); // raw output 0 always lands the win on the attacker's range
            vm.expectRevert("draw not finalized yet");
            attacker.attempt();

            assertFalse(veil.drawn(), "a fully reverted bundle must leave the raffle undrawn");
            vm.roll(block.number + 1);
        }

        assertEq(_balanceOf(address(attacker)), 0, "the attacker must never have collected a prize");

        // The honest, unbundled path still works for the same attacker.
        _drawWithRandomness(0);
        vm.roll(block.number + 1);
        vm.prank(address(attacker));
        veil.claim();
        assertEq(_balanceOf(address(attacker)), TICKET_PRICE, "claiming honestly in a later block must succeed");
    }

    function test_WinningTicket_HasNoGetter() public {
        (bool success,) = address(veil).call(abi.encodeWithSignature("winningTicket()"));
        assertFalse(success, "there must be no public accessor for the winning ticket");
    }

    function test_DrawnEvent_OnlyCarriesTotal() public {
        _enter(alice, 3);
        _enter(bob, 5);
        _closeEntries();

        vm.recordLogs();
        _drawWithRandomness(0);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != address(veil)) continue;
            if (logs[i].topics[0] != keccak256("Drawn(uint256)")) continue;

            found = true;
            assertEq(logs[i].topics.length, 1, "Drawn must have no indexed parameters");
            assertEq(logs[i].data.length, 32, "Drawn's data must be exactly one word, the total");
            assertEq(abi.decode(logs[i].data, (uint256)), 8, "the single word must be the declassified total");
        }

        assertTrue(found, "Drawn event must have been emitted");
    }

    /// @dev The first entrant holds the range that raw RNG output 0 always wins. If the winning
    /// draw were observable through gas or trace differences, a wrapper controlling this range
    /// could distinguish a favorable draw() call from an unfavorable one and choose whether to
    /// keep it. Proving the gas cost is identical either way proves that signal does not exist.
    function test_FirstEntrantWrapper_DrawGasIdenticalWinOrLose() public {
        _enter(alice, 2); // alice's range is [0, 2)
        _enter(bob, 8); // bob's range is [2, 10)
        _closeEntries();

        uint256 snapshot = vm.snapshotState();

        _mockRng(0); // lands in alice's range: a win for the first entrant
        uint256 gasBeforeWin = gasleft();
        veil.draw();
        uint256 gasUsedWin = gasBeforeWin - gasleft();

        vm.revertToState(snapshot);

        _mockRng(9); // lands in bob's range: a loss for the first entrant
        uint256 gasBeforeLose = gasleft();
        veil.draw();
        uint256 gasUsedLose = gasBeforeLose - gasleft();

        assertEq(gasUsedWin, gasUsedLose, "draw() must cost identical gas regardless of who it favors");
    }

    /// @dev Same proof, for the last entrant's range, which is the other boundary an off-chain
    /// wrapper could otherwise try to key its decision on.
    function test_LastEntrantWrapper_DrawGasIdenticalWinOrLose() public {
        _enter(alice, 8); // alice's range is [0, 8)
        _enter(bob, 2); // bob's range is [8, 10), the last entrant
        _closeEntries();

        uint256 snapshot = vm.snapshotState();

        _mockRng(9); // lands in bob's range: a win for the last entrant
        uint256 gasBeforeWin = gasleft();
        veil.draw();
        uint256 gasUsedWin = gasBeforeWin - gasleft();

        vm.revertToState(snapshot);

        _mockRng(0); // lands in alice's range: a loss for the last entrant
        uint256 gasBeforeLose = gasleft();
        veil.draw();
        uint256 gasUsedLose = gasBeforeLose - gasleft();

        assertEq(gasUsedWin, gasUsedLose, "draw() must cost identical gas regardless of who it favors");
    }

    /// @dev Deploys Veil against a token that calls back into claim() during its own payout
    /// transfer. The reentrant call must revert, because claimed is set to true before the
    /// transfer runs, and the original, outer claim() must still complete and pay out exactly
    /// once. This is a defense-in-depth test of Veil's checks-effects-interactions ordering,
    /// not a reproduction of an attack possible against the canonical SRC20 shape Veil actually
    /// uses, since that token's transfer() never calls the recipient.
    function test_Claim_ReentrancyDuringPayoutCannotDoubleClaim() public {
        ReentrantToken reentrantToken = new ReentrantToken();
        Veil reentrantVeil = new Veil(ISRC20(address(reentrantToken)), TICKET_PRICE, DURATION);
        reentrantToken.setVeil(reentrantVeil);

        reentrantToken.mint(address(reentrantToken), suint256(TICKET_PRICE));
        reentrantToken.enterRaffle(suint256(1), suint256(TICKET_PRICE));

        vm.warp(block.timestamp + DURATION);
        _mockRng(0);
        reentrantVeil.draw();
        vm.roll(block.number + 1);

        vm.prank(address(reentrantToken));
        reentrantVeil.claim();

        assertTrue(reentrantToken.reentryAttempted(), "the payout transfer must have attempted to reenter");
        assertFalse(reentrantToken.reentrySucceeded(), "the reentrant claim() call must have reverted");

        vm.prank(address(reentrantToken));
        vm.expectRevert("already claimed");
        reentrantVeil.claim();
    }
}
