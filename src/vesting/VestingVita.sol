// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IVestingVita } from "./IVestingVita.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

/**
 * @title VestingVita
 * @author 0xAtum <https://x.com/0xAtum>
 * @notice Vesting contract
 */
contract VestingVita is Owned, IVestingVita {
  ERC20 public immutable tokenOut;
  uint256 private constant RAY = 10 ** 27;

  uint32 public totalVesting;
  mapping(uint32 => Vesting) private allVestings;
  mapping(address => uint256) private balances;

  constructor(address _owner, address _tokenOut) Owned(_owner) {
    tokenOut = ERC20(_tokenOut);
  }

  /// @inheritdoc IVestingVita
  function createVesting(
    address _receiver,
    uint32 _cliffDurationInSeconds,
    uint32 _vestingDurationInSeconds,
    uint128 _amount,
    bool _canBeCanceled
  ) external override onlyOwner {
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
  ) external override onlyOwner {
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
    uint32 _startTimestamp,
    uint32 _cliffDuration,
    uint32 _endDuration,
    uint128 _amount,
    bool _canBeCanceled
  ) internal {
    if (_receiver == address(0)) revert AddressCannotBeZero();

    uint32 cliff = _startTimestamp + _cliffDuration;
    uint32 end = _startTimestamp + _endDuration;
    uint32 cachedVestingId = totalVesting + 1;
    totalVesting = cachedVestingId;

    if (cliff > end) {
      revert CreateVestingError("Cliff Timestamp > End Timestamp");
    }
    if (_endDuration == 0 || end <= block.timestamp) {
      revert CreateVestingError("End Timestamp is already expired");
    }
    if (_cliffDuration != 0 && cliff <= block.timestamp) {
      revert CreateVestingError("Cliff Timestamp is already expired");
    }

    tokenOut.transferFrom(msg.sender, address(this), _amount);

    Vesting memory vesting = Vesting({
      ratePerSecond: FixedPointMathLib.mulDivDown(_amount, RAY, _endDuration),
      receiver: _receiver,
      totalAmount: _amount,
      claimed: 0,
      start: _startTimestamp,
      cliff: cliff,
      end: end,
      canBeCanceled: _canBeCanceled
    });

    allVestings[cachedVestingId] = vesting;
    balances[_receiver] += _amount;

    emit VestingCreated(cachedVestingId, _receiver, vesting);
  }

  /// @inheritdoc IVestingVita
  function claim(uint32 _vestingSchedule) external override {
    Vesting storage vesting = allVestings[_vestingSchedule];
    if (vesting.receiver != msg.sender) revert NotVestingReceiver();

    uint256 claimed = _claim(_vestingSchedule, vesting);
    if (claimed == 0) revert NothingToClaim();
  }

  /// @inheritdoc IVestingVita
  function cancelVesting(uint32 _vestingSchedule, bool _sendVestedReward)
    external
    override
    onlyOwner
  {
    Vesting storage vesting = allVestings[_vestingSchedule];
    if (vesting.receiver == address(0)) revert VestingNotFound();
    if (!vesting.canBeCanceled) revert VestingCannotBeCanceled();

    uint128 totalAmount = vesting.totalAmount;

    if (_sendVestedReward) {
      _claim(_vestingSchedule, vesting);
    }

    uint256 leftOver = totalAmount - vesting.claimed;

    tokenOut.transfer(msg.sender, leftOver);

    vesting.claimed = totalAmount;
    balances[vesting.receiver] -= leftOver;

    emit VestingCanceled(_vestingSchedule, _sendVestedReward);
  }

  function _claim(uint32 _vestingId, Vesting storage _vesting)
    internal
    returns (uint256 claimed_)
  {
    address receiver = _vesting.receiver;

    uint256 remaining;
    (claimed_, remaining) = _getUnlockedToken(_vesting);

    if (claimed_ == 0) return 0;

    _vesting.claimed += uint128(claimed_);
    balances[receiver] -= claimed_;

    tokenOut.transfer(receiver, claimed_);
    emit VestedClaimed(_vestingId, claimed_, remaining);

    return claimed_;
  }

  /// @inheritdoc IVestingVita
  function getUnlockedToken(uint32 _scheduleId)
    external
    view
    override
    returns (uint256 unlocked_, uint256 remaining_)
  {
    return _getUnlockedToken(allVestings[_scheduleId]);
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
    if (_vesting.end <= block.timestamp) return (totalAmount - _vesting.claimed, 0);

    uint32 timePassed = uint32(block.timestamp - _vesting.start);
    unlocked_ = FixedPointMathLib.mulDivDown(timePassed, _vesting.ratePerSecond, RAY);

    unlocked_ -= _vesting.claimed;
    remaining_ = totalAmount - unlocked_;

    return (unlocked_, remaining_);
  }

  /// @inheritdoc IVestingVita
  function tokenOutBalanceOf(address _wallet) external view override returns (uint256) {
    return balances[_wallet];
  }

  /// @inheritdoc IVestingVita
  function getVestingSchedule(uint32 _vestingId)
    external
    view
    override
    returns (Vesting memory)
  {
    return allVestings[_vestingId];
  }
}
