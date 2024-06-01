// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IVestingVita {
  error CreateVestingError(string);
  error NothingToClaim();

  struct Vesting {
    uint256 ratePerSecond;
    uint128 totalAmount;
    uint128 claimed;
    address receiver;
    uint32 start;
    uint32 cliff;
    uint32 end;
    bool canBeCanceled;
  }

  event VestingCanceled(uint32 indexed scheduleId, bool vestedRewardSent);
  event VestedClaimed(uint32 indexed scheduleId, uint256 claimed, uint256 remaining);

  error NotVestingReceiver();

  /**
   * @notice Create A vesting starting at the execution time
   * @param _receiver Wallet that will be receiving the vested reward
   * @param _cliffDurationInSeconds Duration in seconds of the cliff
   * @param _vestingDurationInSeconds Duration in seconds of the vesting
   * @param _amount Amount allocated to the vesting
   * @param _canBeCanceled Can be canceled later
   * @dev OnlyOwner function
   */
  function createVesting(
    address _receiver,
    uint32 _cliffDurationInSeconds,
    uint32 _vestingDurationInSeconds,
    uint128 _amount,
    bool _canBeCanceled
  ) external;

  /**
   * @notice Create A vesting at specific start point
   * @param _receiver Wallet that will be receiving the vested reward
   * @param _startTimestamp Start timestamp of the vesting
   * @param _cliffDurationInSeconds Duration in seconds of the cliff
   * @param _vestingDurationInSeconds Duration in seconds of the vesting
   * @param _amount Amount allocated to the vesting
   * @param _canBeCanceled Can be canceled later
   * @dev OnlyOwner function
   */
  function createVestingWithStartPoint(
    address _receiver,
    uint32 _startTimestamp,
    uint32 _cliffDurationInSeconds,
    uint32 _vestingDurationInSeconds,
    uint128 _amount,
    bool _canBeCanceled
  ) external;

  /**
   * @notice claim vested tokens
   * @param _vestingSchedule Id of the schedule
   */
  function claim(uint32 _vestingSchedule) external;

  /**
   * @notice cancel an on-going vesting if allowed
   * @param _vestingSchedule Id of the vesting
   * @param _sendVestedReward Send the vested reward to the receiver
   * @dev OnlyOwner Function
   */
  function cancelVesting(uint32 _vestingSchedule, bool _sendVestedReward) external;

  /**
   * @notice get how many vested tokens ready to be claimed
   * @param _scheduleId Id of the vesting schedule
   */
  function getUnlockedToken(uint32 _scheduleId) external view returns (uint256 unlocked_);

  /**
   * @notice get the `TOKEN_OUT`'s balance of a `_wallet`
   * @param _wallet address of the `_wallet`
   * @return balance Total `TOKEN_OUT` of the `_wallet`, vested and vesting
   */
  function balanceOf(address _wallet) external view returns (uint256);
}
