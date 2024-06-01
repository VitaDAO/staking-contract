// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IVestingVita } from "./IVestingVita.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

/**
 * @title VestingVita
 * @author 0xAtum <0xAtum@protonmail.com>
 * @notice Vesting contract
 */
contract VestingVita is Owned, IVestingVita {
  ERC20 public constant TOKEN_OUT = ERC20(0x81f8f0bb1cB2A06649E51913A151F0E7Ef6FA321);
  uint256 private constant RAY = 10 ** 27;

  uint32 public totalVesting;
  mapping(uint32 => Vesting) private allVestings;
  mapping(address => uint256) private balances;

  constructor(address _owner) Owned(_owner) { }

  /// @inheritdoc IVestingVita
  function createVesting(
    address _receiver,
    uint32 _cliffDurationInSeconds,
    uint32 _vestingDurationInSeconds,
    uint128 _amount,
    bool _canBeCanceled
  ) external onlyOwner {
    _create(
      _receiver,
      uint32(block.timestamp),
      _cliffDurationInSeconds,
      _vestingDurationInSeconds,
      _amount,
      _canBeCanceled
    );
  }

  /// @inheritdoc IVestingVita
  function createVestingWithStartPoint(
    address _receiver,
    uint32 _startTimestamp,
    uint32 _cliffDurationInSeconds,
    uint32 _vestingDurationInSeconds,
    uint128 _amount,
    bool _canBeCanceled
  ) external onlyOwner {
    _create(
      _receiver,
      _startTimestamp,
      _cliffDurationInSeconds,
      _vestingDurationInSeconds,
      _amount,
      _canBeCanceled
    );
  }

  function _create(
    address _receiver,
    uint32 _start,
    uint32 _cliff,
    uint32 _end,
    uint128 _amount,
    bool _canBeCanceled
  ) internal {
    if (_start > _end) {
      revert CreateVestingError("Start Timestamp is higher than the End Timestamp");
    }
    if (_start > _cliff) {
      revert CreateVestingError("Start Timestamp is higher than the Cliff Timestamp");
    }
    if (_cliff > _end) {
      revert CreateVestingError("Cliff Timestamp is higher than the End Timestamp");
    }

    TOKEN_OUT.transfer(msg.sender, _amount);

    uint32 cachedTotalVesting = totalVesting + 1;
    totalVesting = cachedTotalVesting;

    allVestings[cachedTotalVesting] = Vesting({
      ratePerSecond: FixedPointMathLib.mulDivDown(_amount, RAY, _end - _start),
      receiver: _receiver,
      totalAmount: _amount,
      claimed: 0,
      start: _start,
      cliff: uint32(block.timestamp + _cliff),
      end: uint32(block.timestamp + _end),
      canBeCanceled: _canBeCanceled
    });

    balances[_receiver] += _amount;
  }

  /// @inheritdoc IVestingVita
  function claim(uint32 _vestingSchedule) external {
    Vesting storage vesting = allVestings[_vestingSchedule];
    if (vesting.receiver != msg.sender) revert NotVestingReceiver();

    uint256 claimed = _claim(_vestingSchedule, vesting);
    if (claimed == 0) revert NothingToClaim();
  }

  /// @inheritdoc IVestingVita
  function cancelVesting(uint32 _vestingSchedule, bool _sendVestedReward)
    external
    onlyOwner
  {
    Vesting storage vesting = allVestings[_vestingSchedule];
    uint128 totalAmount = vesting.totalAmount;

    if (_sendVestedReward) {
      _claim(_vestingSchedule, vesting);
    }

    TOKEN_OUT.transfer(msg.sender, totalAmount - vesting.claimed);

    vesting.claimed = totalAmount;
    balances[vesting.receiver] = 0;

    emit VestingCanceled(_vestingSchedule, _sendVestedReward);
  }

  function _claim(uint32 _vestingId, Vesting storage _vesting)
    internal
    returns (uint256 claimed_)
  {
    uint256 remaining;
    (claimed_, remaining) = _getUnlockedToken(_vesting);

    if (claimed_ == 0) return 0;

    _vesting.claimed += uint128(claimed_);
    balances[msg.sender] -= claimed_;

    TOKEN_OUT.transfer(_vesting.receiver, claimed_);
    emit VestedClaimed(_vestingId, claimed_, remaining);

    return claimed_;
  }

  /// @inheritdoc IVestingVita
  function getUnlockedToken(uint32 _scheduleId) external view returns (uint256 unlocked_) {
    (unlocked_,) = _getUnlockedToken(allVestings[_scheduleId]);
    return unlocked_;
  }

  function _getUnlockedToken(Vesting storage _vesting)
    internal
    view
    returns (uint256 unlocked_, uint256 remaining_)
  {
    uint256 totalAmount = _vesting.totalAmount;

    if (_vesting.cliff > block.timestamp || _vesting.claimed >= totalAmount) {
      return (0, totalAmount);
    }
    if (_vesting.end < block.timestamp) return (totalAmount - _vesting.claimed, 0);

    uint32 timePassed = uint32(block.timestamp - _vesting.start);
    unlocked_ = FixedPointMathLib.mulDivDown(timePassed, _vesting.ratePerSecond, RAY);

    return (unlocked_ - _vesting.claimed, totalAmount - unlocked_);
  }

  /// @inheritdoc IVestingVita
  function balanceOf(address _wallet) external view returns (uint256) {
    return balances[_wallet];
  }
}
