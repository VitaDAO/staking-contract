// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IStakingVita {
  enum ScheduleDuration {
    THREE_MONTHS,
    SIX_MONTHS,
    TWELVE_MONTHS,
    TWENTY_FOUR_MONTHS,
    THIRTY_SIX_MONTHS
  }

  struct StakingSchedule {
    address owner;
    uint128 amount;
    uint32 end;
    ScheduleDuration lockSchedule;
    bool withdrawn;
  }

  error NotEnoughTokenOut();
  error NotStakingOwner();
  error ScheduleNotFinished();
  error StakingAlreadyWithdrawn();

  event Stake(
    address indexed wallet,
    uint32 indexed stakeId,
    ScheduleDuration scheduleDuration,
    uint128 stakedAmount
  );
  event Unstaked(
    address indexed wallet, uint32 indexed stakeId, bool forced, bool ignoreBurning
  );

  /**
   * @notice Stake `tokenIn` and received the Staked Version of the Token.
   * @param _duration Schedule Lock Duration Mode.
   * @param _amount Amount to lock.
   */
  function stake(ScheduleDuration _duration, uint128 _amount) external;

  /**
   * @notice batch unstake StakingSchedule.
   * @param _scheduleIds All StakingSchedule IDs to unstake.
   */
  function batchUnstake(uint32[] calldata _scheduleIds) external;

  /**
   * @notice unstake a StakingSchedule.
   * @param _scheduleId Id of the StakingSchedule.
   */
  function unstake(uint32 _scheduleId) external;

  /**
   * @notice Ignore StakingSchedule's lock and unstake
   * @param _scheduleId Id of the StakingSchedule
   * @dev OnlyOwner function
   */
  function forceUnstake(uint32 _scheduleId) external;

  /**
   * @notice Ignore StakingSchedule's Lock and the StakedToken burn function
   * @param _scheduleId Id of the StakingSchedule
   * @dev OnlyOwner function
   */
  function forceUnstakeIgnoreBurning(uint32 _scheduleId) external;

  /**
   * @notice Get StakingSchedule data
   * @param _scheduleId Id of the Schedule
   * @return stakingSchedule tuple(address owner, uint128 amount, uint32 end,
   * ScheduleDuration lockSchedule, bool withdrawn)
   */
  function getStakingSchedule(uint32 _scheduleId)
    external
    view
    returns (StakingSchedule memory);

  /**
   * @notice Get Total `tokenIn` staked by the `_wallet`
   * @param _wallet Address to look upon
   * @return totalStaked Total `tokenIn` staked by the `_wallet`
   */
  function getTotalStaked(address _wallet) external view returns (uint256);
}
