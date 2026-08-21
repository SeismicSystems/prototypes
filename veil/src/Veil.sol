// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ISRC20} from "./ISRC20.sol";

/// @title Veil
/// @notice A raffle where ticket stakes stay hidden until the draw, and the winner's identity
///         stays hidden until they choose to claim.
/// @dev Entrants buy tickets by pulling payment through a shielded SRC20 token, so the amount
///      moved never appears as a public transaction field. Each entrant's ticket range is
///      carved out of a pool total that stays encrypted until the draw declassifies it. The
///      winning ticket number itself is never declassified, so there is nothing for anyone,
///      including the entrant who triggers the draw, to read and react to. The only way to
///      learn anything about the outcome is to call claim, in a later block than the draw, which
///      reveals only whether the caller's own private range happens to cover it.
contract Veil {
    /// @dev An entrant's private stake in the pool, plus their public claim state
    struct Entrant {
        suint256 rangeStart;
        suint256 rangeEnd;
        bool hasEntered;
        bool claimed;
    }

    /// @notice The token entrants pay with and the token the prize is paid out in
    ISRC20 public immutable ticketToken;

    /// @notice Cost of a single ticket, denominated in ticketToken units
    uint256 public immutable ticketPrice;

    /// @notice Timestamp after which entries close and the raffle can be drawn
    uint256 public immutable entryDeadline;

    /// @notice Total tickets sold, hidden until draw() declassifies it
    suint256 private totalTickets;

    /// @notice Set once the draw has run
    bool public drawn;

    /// @notice The block the draw ran in
    /// @dev claim() may only run in a later block, so the draw and the check of its outcome
    ///      can never be bundled into one atomic, revertible transaction
    uint256 public drawBlock;

    /// @notice The winning ticket number, set at draw time
    /// @dev Never declassified. There is no getter and no event field for this value. The only
    ///      way to learn anything about it is to call claim, which reveals nothing beyond
    ///      whether the caller's own range covers it.
    suint256 private winningTicket;

    /// @notice Total tickets sold, declassified at draw time
    /// @dev Equal to the pool's ticketToken balance divided by ticketPrice
    uint256 public totalTicketsSold;

    mapping(address => Entrant) private entrants;

    /// @dev Ticket count is intentionally not part of this event, and neither is the winning
    ///      ticket number
    event Entered(address indexed entrant);
    event Drawn(uint256 totalTicketsSold);
    event Claimed(address indexed winner, uint256 prize);

    constructor(ISRC20 _ticketToken, uint256 _ticketPrice, uint256 _duration) {
        require(address(_ticketToken) != address(0), "ticket token cannot be the zero address");
        require(_ticketPrice > 0, "ticket price must be positive");
        require(_duration > 0, "duration must be positive");
        ticketToken = _ticketToken;
        ticketPrice = _ticketPrice;
        entryDeadline = block.timestamp + _duration;
    }

    /// @notice Buy tickets before the deadline. Each address may enter once.
    /// @dev Requires a prior approve() on the ticket token for at least ticketPrice * numTickets
    /// @param numTickets Number of tickets to buy, encrypted end to end
    function enter(suint256 numTickets) external {
        require(block.timestamp < entryDeadline, "entries are closed");
        require(numTickets > suint256(0), "must buy at least one ticket");
        require(!entrants[msg.sender].hasEntered, "already entered");

        bool success = ticketToken.transferFrom(msg.sender, address(this), suint256(ticketPrice) * numTickets);
        require(success, "payment failed");

        suint256 start = totalTickets;
        totalTickets = start + numTickets;

        entrants[msg.sender] =
            Entrant({rangeStart: start, rangeEnd: start + numTickets, hasEntered: true, claimed: false});

        emit Entered(msg.sender);
    }

    /// @notice Draw the winning ticket once entries have closed
    /// @dev Declassifies the ticket total so a winning number can be chosen from it, but the
    ///      winning number itself stays shielded. Nothing here depends on the drawn value, so
    ///      this call always succeeds once its preconditions hold, and can never be bundled
    ///      with a later, outcome-dependent revert.
    function draw() external {
        require(block.timestamp >= entryDeadline, "entries still open");
        require(!drawn, "already drawn");

        uint256 total = uint256(totalTickets);
        require(total > 0, "no entrants");

        drawn = true;
        drawBlock = block.number;
        totalTicketsSold = total;
        winningTicket = unsafe_rng_u256() % suint256(total);

        emit Drawn(total);
    }

    /// @notice Claim the prize if your ticket range covers the winning number
    /// @dev Callable only in a block after the draw, so this can never be bundled atomically
    ///      with draw() itself. The shielded comparison below is the only place in the contract
    ///      where the drawn value is touched, and it runs once, for the caller alone. Its
    ///      outcome, revert or success, is the only thing anyone learns about the caller's
    ///      private range.
    function claim() external {
        require(drawn, "not drawn yet");
        require(block.number > drawBlock, "draw not finalized yet");

        Entrant storage entrant = entrants[msg.sender];
        require(entrant.hasEntered, "did not enter");
        require(!entrant.claimed, "already claimed");

        require(winningTicket >= entrant.rangeStart && winningTicket < entrant.rangeEnd, "not the winner");

        entrant.claimed = true;
        uint256 prize = ticketPrice * totalTicketsSold;

        bool success = ticketToken.transfer(msg.sender, suint256(prize));
        require(success, "payout failed");

        emit Claimed(msg.sender, prize);
    }
}
