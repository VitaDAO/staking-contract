// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { IStakingVita } from "./IStakingVita.sol";

/**
 * @title StakingVita
 * @author 0xAtum <0xAtum@protonmail.com>
 * @notice Stake and lock the `TOKEN_IN` for a defined period of time in exchange of the
 * staked version of the token
 */
contract StakingVita is IStakingVita, ERC20, Owned {
  ERC20 public constant TOKEN_IN = ERC20(0x81f8f0bb1cB2A06649E51913A151F0E7Ef6FA321);
  uint32 private constant MONTH_IN_SECONDS = 2_629_800;

  uint32[] public DURATIONS = [
    3 * MONTH_IN_SECONDS,
    6 * MONTH_IN_SECONDS,
    12 * MONTH_IN_SECONDS,
    24 * MONTH_IN_SECONDS,
    36 * MONTH_IN_SECONDS
  ];

  uint32 public totalStakeSchedules;
  mapping(uint32 => StakingSchedule) private allStakings;
  mapping(address => uint256) private stakedBalances;

  constructor(address _owner) ERC20("Staked Vita", "stVITA", 18) Owned(_owner) { }

  /// @inheritdoc IStakingVita
  function stake(ScheduleDuration _duration, uint128 _amount) external {
    uint32 cachedTotalVesting = totalStakeSchedules + 1;
    totalStakeSchedules = cachedTotalVesting;

    allStakings[cachedTotalVesting] = StakingSchedule({
      owner: msg.sender,
      amount: _amount,
      end: uint32(block.timestamp) + DURATIONS[uint8(_duration)],
      lockSchedule: _duration,
      withdrawn: false
    });

    stakedBalances[msg.sender] += _amount;
    TOKEN_IN.transferFrom(msg.sender, address(this), _amount);
    _mint(msg.sender, _amount);

    emit Stake(msg.sender, cachedTotalVesting, _duration, _amount);
  }

  /// @inheritdoc IStakingVita
  function batchUnstake(uint32[] calldata _scheduleIds) external {
    for (uint256 i = 0; i < _scheduleIds.length; ++i) {
      _unstake(_scheduleIds[i], false, false);
    }
  }

  /// @inheritdoc IStakingVita
  function unstake(uint32 _scheduleId) external {
    _unstake(_scheduleId, false, false);
  }

  /// @inheritdoc IStakingVita
  function forceUnstake(uint32 _scheduleId) external onlyOwner {
    _unstake(_scheduleId, true, false);
  }

  /// @inheritdoc IStakingVita
  function forceUnstakeIgnoreBurning(uint32 _scheduleId) external onlyOwner {
    _unstake(_scheduleId, true, true);
  }

  function _unstake(uint32 _scheduleId, bool _isForce, bool _ignoreBurning) internal {
    StakingSchedule storage staking = allStakings[_scheduleId];
    address receiver = staking.owner;

    if (!_isForce) {
      if (msg.sender != receiver) revert NotVestingOwner();
      if (staking.end > block.timestamp) revert ScheduleNotFinished();
    }

    uint256 returning = staking.amount;
    stakedBalances[receiver] -= returning;

    if (!_ignoreBurning) {
      _burn(receiver, returning);
    }

    TOKEN_IN.transfer(receiver, returning);

    emit Unstaked(receiver, _scheduleId, _isForce);
  }

  /// @inheritdoc IStakingVita
  function getStakingSchedule(uint32 _scheduleId)
    external
    view
    returns (StakingSchedule memory)
  {
    return allStakings[_scheduleId];
  }

  /// @inheritdoc IStakingVita
  function getTotalStaked(address _wallet) external view returns (uint256) {
    return stakedBalances[_wallet];
  }
}
