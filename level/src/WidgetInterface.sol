// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

import {ISRC20} from "./SRC20.sol";
import {WDGSRC20} from "./WDGSRC20.sol";
import {PermissionedAMM} from "./PermissionedAMM.sol";

/// @title WidgetInterface - DePIN Operator Reward Price Floor Protocol
/// @notice This contract implements a price floor mechanism for DePIN operator rewards,
/// ensuring operators can liquidate their rewards at a minimum guaranteed price.
/// @dev Uses an AMM to maintain a price floor and implements epoch-based withdrawal limits
/// to manage protocol liquidity
contract WidgetInterface {
    address public rewardOracle;
    uint256 public constant BLOCKS_PER_EPOCH = 7200; // about a day
    suint256 private maxWithdrawalPerEpoch; // the max usdc that can be withdrawn per epoch

    PermissionedAMM public amm;
    WDGSRC20 public WDG;
    ISRC20 public USDC;

    mapping(saddress => suint256) epochWithdrawalAmt;
    mapping(saddress => suint256) lastWithdrawalEpoch;

    modifier onlyOracle() {
        require(msg.sender == rewardOracle, "Only the oracle can call this function");
        _;
    }

    /// @notice Initializes the price floor protocol
    /// @param _wdg Address of the operator reward token (WDG)
    /// @param _usdc Address of the stablecoin used for payments/withdrawals
    /// @param _rewardOracle Address authorized to distribute operator rewards
    /// @param _maxWithdrawalPerEpoch Maximum USDC that can be withdrawn per epoch to manage protocol liquidity
    constructor(
        address _wdg,
        address _usdc,
        address _rewardOracle,
        suint256 _maxWithdrawalPerEpoch,
        suint256 _transferUnlockTime
    ) {
        rewardOracle = _rewardOracle;
        WDG = WDGSRC20(_wdg);
        USDC = ISRC20(_usdc);
        maxWithdrawalPerEpoch = _maxWithdrawalPerEpoch;
        amm = new PermissionedAMM(_wdg, _usdc);

        // set the wdg trusted addresses
        WDG.setTrustedDePinServiceAddress(address(this));
        WDG.setTrustedAMMAddress(address(amm));
        WDG.setTransferUnlockTime(_transferUnlockTime);
    }

    /// @notice Processes user payments for DePIN services
    /// @dev Payments are used to maintain the price floor through token buybacks
    /// @param usdcAmount Amount of USDC to pay for services
    function payForService(suint256 usdcAmount) public {
        // transfer USDC from user to this contract
        // it is assumed the transfer is approved before calling this function
        USDC.transferFrom(saddress(msg.sender), saddress(this), usdcAmount);

        // user payments are distributed to token holders / operators
        // through token buybacks in the AMM
        _serviceBuyback(usdcAmount);

        //
        // PLACEHOLDER
        // normally business logic would go here
        // but this is a dummy function
        //
    }

    /// @notice Internal buyback mechanism to maintain price floor
    /// @dev Converts service payments to WDG tokens and burns them, supporting token value
    /// @param usdcAmount Amount of USDC to use for buyback
    function _serviceBuyback(suint256 usdcAmount) internal {
        // 1) swap USDC into WDG through the AMM
        USDC.approve(saddress(amm), usdcAmount);
        amm.swap(saddress(USDC), usdcAmount);
        // 2) and burn the WDG token that is swapped out
        WDG.burn(saddress(this), suint(WDG.balanceOf())); // assumed there is no reason for this contract to have a WDG balance
    }

    /// @notice Distributes reward tokens to operators for their services
    /// @dev Only callable by the oracle which determines reward distribution
    /// @param operator Address of the DePIN operator
    /// @param amount Amount of WDG tokens to mint as reward
    function allocateReward(saddress operator, suint256 amount) external onlyOracle {
        WDG.mint(operator, amount); // double check this is the correct token
    }

    /// @notice Checks operator's remaining withdrawal capacity for the current epoch
    /// @dev Enforces epoch-based withdrawal limits to manage protocol liquidity
    /// @return Maximum amount of USDC that can currently be withdrawn in current epoch
    function calcWithdrawalCap() internal returns (suint256) {
        // reset the withdrawal cap if the user has not withdrawn in the current epoch
        suint256 currentEpoch = suint(block.number) / suint(BLOCKS_PER_EPOCH);
        if (currentEpoch > lastWithdrawalEpoch[saddress(msg.sender)]) {
            epochWithdrawalAmt[saddress(msg.sender)] = suint(0);
            lastWithdrawalEpoch[saddress(msg.sender)] = currentEpoch;
        } else {
            require(epochWithdrawalAmt[saddress(msg.sender)] == suint(0), "Already withdrawn this period.");
        }

        suint256 usdcBalance = suint256(amm.calcSwapOutput(suint256(WDG.trustedBalanceOf(saddress(msg.sender)))));
        return _min(maxWithdrawalPerEpoch, usdcBalance);
    }

    // user facing function to view their current withdrawal cap
    function viewWithdrawalCap() public returns (uint256) {
        return uint256(calcWithdrawalCap());
    }

    /// @notice Allows operators to liquidate their reward tokens at the guaranteed minimum price
    /// @dev Converts WDG to USDC through AMM at the protocol-maintained price floor
    /// @param _amount Amount of USDC to withdraw
    function operatorWithdraw(suint256 _amount) public {
        suint256 withdrawalCap = calcWithdrawalCap(); // max usdc that user can withdraw
        require(_amount <= withdrawalCap, "Overdrafting daily withdrawal limit or insufficient balance.");

        // calculate and swap amount of wdg for usdc
        suint256 amountWdgIn = suint256(amm.calcSwapInput(address(USDC), _amount));
        WDG.transferFrom(saddress(msg.sender), saddress(this), amountWdgIn);

        amm.swapOut(saddress(USDC), _amount); //
        USDC.transfer(saddress(msg.sender), suint(USDC.balanceOf()));
        // USDC balance for this contract should be zero except during operatorWithdraw calls
        epochWithdrawalAmt[saddress(msg.sender)] += _amount;
    }

    /// @notice Utility function to return the minimum of two values
    /// @param x First value
    /// @param y Second value
    /// @return Minimum of x and y
    function _min(suint256 x, suint256 y) private pure returns (suint256) {
        return x <= y ? x : y;
    }
}
