// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { ILockingVita } from "./ILockingVita.sol";

/**
 * @title LockingVita
 * @author 0xAtum <https://x.com/0xAtum>
 * @notice Lock `tokenIn` for a defined period of time in exchange of the Locked version
 * of this token
 */
contract LockingVita is ILockingVita, ERC20, Owned {
  ERC20 public immutable tokenIn;
  uint32 private constant MONTH_IN_SECONDS = 2_629_800;

  uint32[] public DURATIONS = [
    3 * MONTH_IN_SECONDS,
    6 * MONTH_IN_SECONDS,
    12 * MONTH_IN_SECONDS,
    24 * MONTH_IN_SECONDS,
    36 * MONTH_IN_SECONDS
  ];

  uint32 public totalLockSchedules;
  mapping(uint32 => LockingShedule) private lockingSchedules;
  mapping(address => uint256) private lockedBalances;

  constructor(address _owner, address _tokenIn)
    ERC20("Locked Vita", "stVITA", 18)
    Owned(_owner)
  {
    tokenIn = ERC20(_tokenIn);
  }

  /// @inheritdoc ILockingVita
  function lock(ScheduleDuration _duration, uint128 _amount) external override {
    uint32 nextScheduleId = totalLockSchedules + 1;
    totalLockSchedules = nextScheduleId;

    lockingSchedules[nextScheduleId] = LockingShedule({
      locker: msg.sender,
      amount: _amount,
      end: uint32(block.timestamp) + DURATIONS[uint8(_duration)],
      duration: _duration,
      withdrawn: false
    });

    lockedBalances[msg.sender] += _amount;
    tokenIn.transferFrom(msg.sender, address(this), _amount);
    _mint(msg.sender, _amount);

    emit Locked(msg.sender, nextScheduleId, _duration, _amount);
  }

  /// @inheritdoc ILockingVita
  function batchUnlock(uint32[] calldata _scheduleIds) external override {
    for (uint256 i = 0; i < _scheduleIds.length; ++i) {
      _executeUnlock(_scheduleIds[i], false, false);
    }
  }

  /// @inheritdoc ILockingVita
  function unlock(uint32 _scheduleId) external override {
    _executeUnlock(_scheduleId, false, false);
  }

  /// @inheritdoc ILockingVita
  function forceUnlock(uint32 _scheduleId) external override onlyOwner {
    _executeUnlock(_scheduleId, true, false);
  }

  /// @inheritdoc ILockingVita
  function forceUnlockIgnoreBurning(uint32 _scheduleId) external override onlyOwner {
    _executeUnlock(_scheduleId, true, true);
  }

  function _executeUnlock(uint32 _scheduleId, bool _isForce, bool _ignoreBurning)
    internal
  {
    LockingShedule storage schedule = lockingSchedules[_scheduleId];
    address recipient = schedule.locker;

    if (schedule.withdrawn) revert StakingAlreadyWithdrawn();

    if (!_isForce) {
      if (msg.sender != recipient) revert NotStakingOwner();
      if (schedule.end > block.timestamp) revert ScheduleNotFinished();
    }

    uint256 returning = schedule.amount;
    lockedBalances[recipient] -= returning;
    schedule.withdrawn = true;

    if (!_ignoreBurning) {
      _burn(recipient, returning);
    }

    tokenIn.transfer(recipient, returning);

    emit Unlocked(recipient, _scheduleId, _isForce, _ignoreBurning);
  }

  /// @inheritdoc ILockingVita
  function getLockingShedule(uint32 _scheduleId)
    external
    view
    override
    returns (LockingShedule memory)
  {
    return lockingSchedules[_scheduleId];
  }

  /// @inheritdoc ILockingVita
  function getTotalLocked(address _locker) external view override returns (uint256) {
    return lockedBalances[_locker];
  }
}
