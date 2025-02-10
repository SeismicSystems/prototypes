// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

contract Walnut {
    uint256 startShell;
    uint256 shell;

    suint256 startNumber;
    suint256 number;

    event Hit(uint256 remaining);
    event Shake();
    event Reset(uint256 remaining);

    constructor(uint256 _shell, suint256 _number) {
        startShell = _shell;
        shell = _shell;

        startNumber = _number;
        number = _number;
    }

    function hit() public {
        if (shell > 0) shell--;
        emit Hit(shell);
    }

    function shake() public {
        number++;
        emit Shake();
    }

    function reset() public {
        shell = startShell;
        number = startNumber;
        emit Reset(shell);
    }

    function look() public view requireCracked returns (uint256) {
        return uint256(number);
    }

    modifier requireCracked() {
        if (shell > 0) revert("SHELL_INTACT");
        _;
    }
}
