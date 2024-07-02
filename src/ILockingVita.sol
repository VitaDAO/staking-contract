// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ILockingVita {
  enum ScheduleDuration {
    THREE_MONTHS,
    SIX_MONTHS,
    TWELVE_MONTHS,
    TWENTY_FOUR_MONTHS,
    THIRTY_SIX_MONTHS
  }

  struct LockingShedule {
    address locker;
    uint128 amount;
    uint32 end;
    ScheduleDuration duration;
    bool withdrawn;
  }

  error NotEnoughTokenOut();
  error NotStakingOwner();
  error ScheduleNotFinished();
  error StakingAlreadyWithdrawn();

  event Locked(
    address indexed locker,
    uint32 indexed scheduleId,
    ScheduleDuration duration,
    uint128 amount
  );
  event Unlocked(
    address indexed locker, uint32 indexed scheduleId, bool forced, bool ignoreBurning
  );

  /**
   * @notice Lock `tokenIn` and received the Locked Version of the Token.
   * @param _duration Schedule Lock Duration Mode.
   * @param _amount Amount to lock.
   */
  function lock(ScheduleDuration _duration, uint128 _amount) external;

  /**
   * @notice batch unlock LockingShedule.
   * @param _scheduleIds All LockingShedule IDs to unlock.
   */
  function batchUnlock(uint32[] calldata _scheduleIds) external;

  /**
   * @notice unlock a LockingShedule.
   * @param _scheduleId Id of the LockingShedule.
   */
  function unlock(uint32 _scheduleId) external;

  /**
   * @notice Ignore LockingShedule's lock and unlock
   * @param _scheduleId Id of the LockingShedule
   * @dev OnlyOwner function
   */
  function forceUnlock(uint32 _scheduleId) external;

  /**
   * @notice Ignore LockingShedule's Lock and the LockedToken burn function
   * @param _scheduleId Id of the LockingShedule
   * @dev OnlyOwner function
   */
  function forceUnlockIgnoreBurning(uint32 _scheduleId) external;

  /**
   * @notice Get LockingShedule data
   * @param _scheduleId Id of the Schedule
   * @return lockingSchedule tuple(address owner, uint128 amount, uint32 end,
   * ScheduleDuration duration, bool withdrawn)
   */
  function getLockingShedule(uint32 _scheduleId)
    external
    view
    returns (LockingShedule memory);

  /**
   * @notice Get Total `tokenIn` lockd by the `_locker`
   * @param _locker Address to look upon
   * @return totalLocked Total `tokenIn` lockd by the `_locker`
   */
  function getTotalLocked(address _locker) external view returns (uint256);
}
