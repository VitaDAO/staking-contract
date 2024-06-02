// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.25;

import "../base/BaseTest.t.sol";
import { StakingVita, IStakingVita } from "src/staking/StakingVita.sol";

import { MockERC20 } from "test/mock/contract/MockERC20.t.sol";

contract StakingVitaTest is BaseTest {
  address private owner;
  address private user;

  StakingVitaHarness private underTest;
  MockERC20 private tokenIn;

  uint128[] depositAmounts;
  uint32[] scheduleIds;

  function setUp() external {
    delete depositAmounts;
    delete scheduleIds;

    createVariables();

    underTest = new StakingVitaHarness(owner);

    tokenIn = MockERC20(address(underTest.TOKEN_IN()));
    vm.etch(address(tokenIn), address(new MockERC20("Mock Token", "MT", 18)).code);

    tokenIn.mint(user, 100e18);
  }

  function createVariables() internal {
    owner = generateAddress("Owner");
    user = generateAddress("User");
  }

  function test_constructor_thenContractConfiguredCorrectly() external {
    underTest = new StakingVitaHarness(owner);

    assertEq(underTest.owner(), owner);
    assertEq(abi.encode(underTest.name()), abi.encode("Staked Vita"));
    assertEq(abi.encode(underTest.symbol()), abi.encode("stVITA"));
    assertEq(underTest.decimals(), 18);

    assertEq(address(underTest.TOKEN_IN()), 0x81f8f0bb1cB2A06649E51913A151F0E7Ef6FA321);

    uint8 totalEnums = uint8(type(IStakingVita.ScheduleDuration).max);

    assertEq(totalEnums, 4);

    assertEq(
      underTest.DURATIONS(uint8(IStakingVita.ScheduleDuration.THREE_MONTHS)), 7_889_400
    );
    assertEq(
      underTest.DURATIONS(uint8(IStakingVita.ScheduleDuration.SIX_MONTHS)), 15_778_800
    );
    assertEq(
      underTest.DURATIONS(uint8(IStakingVita.ScheduleDuration.TWELVE_MONTHS)), 31_557_600
    );
    assertEq(
      underTest.DURATIONS(uint8(IStakingVita.ScheduleDuration.TWENTY_FOUR_MONTHS)),
      63_115_200
    );
    assertEq(
      underTest.DURATIONS(uint8(IStakingVita.ScheduleDuration.THIRTY_SIX_MONTHS)),
      94_672_800
    );
  }

  function test_stake_thenCreatesStakingSchedule() external prankAs(user) {
    uint8 totalEnums = uint8(type(IStakingVita.ScheduleDuration).max) + 1;
    depositAmounts = [13e18, 9.2e18, 0.1e18, 23.33e18, 44e18];

    uint128 totalAmount = 0;
    uint128 currentAmount = 0;
    IStakingVita.ScheduleDuration scheduleDuration;
    IStakingVita.StakingSchedule memory expectedStakingSchedule;

    for (uint32 i = 0; i < totalEnums; ++i) {
      currentAmount = depositAmounts[i];
      scheduleDuration = IStakingVita.ScheduleDuration(i);
      totalAmount += currentAmount;

      expectedStakingSchedule = IStakingVita.StakingSchedule({
        owner: user,
        amount: currentAmount,
        end: uint32(block.timestamp) + underTest.DURATIONS(uint8(scheduleDuration)),
        lockSchedule: scheduleDuration,
        withdrawn: false
      });

      expectExactEmit();
      emit IStakingVita.Stake(user, uint32(i + 1), scheduleDuration, currentAmount);

      underTest.stake(scheduleDuration, currentAmount);

      assertEq(
        abi.encode(underTest.getStakingSchedule(i + 1)),
        abi.encode(expectedStakingSchedule)
      );

      skip(1.2 days);
    }

    assertEq(underTest.getTotalStaked(user), totalAmount);
    assertEq(underTest.balanceOf(user), totalAmount);
    assertEq(tokenIn.balanceOf(address(underTest)), totalAmount);
    assertEq(underTest.totalStakeSchedules(), totalEnums);
  }

  function test_batchUnstake_thenUnstakes() external prankAs(user) {
    depositAmounts = [13e18, 9.2e18, 0.1e18, 23.33e18, 44e18];

    for (uint256 i = 0; i < depositAmounts.length; ++i) {
      underTest.stake(IStakingVita.ScheduleDuration(0), depositAmounts[i]);
    }

    skip(30 days * 10);

    uint256 balanceBeforeStakedToken = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    scheduleIds = [2, 1, 4];
    uint256 totalUnstaking = 0;

    for (uint256 i = 0; i < scheduleIds.length; ++i) {
      totalUnstaking += depositAmounts[scheduleIds[i] - 1];

      expectExactEmit();
      emit IStakingVita.Unstaked(user, scheduleIds[i], false, false);
    }
    underTest.batchUnstake(scheduleIds);

    assertEq(balanceBeforeStakedToken - underTest.balanceOf(user), totalUnstaking);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, totalUnstaking);
  }

  function test_unstake_thenUnstake() external prankAs(user) {
    uint128 staking = 23.2e18;
    uint32 stakingId = 1;
    underTest.stake(IStakingVita.ScheduleDuration(0), staking);

    skip(30 days * 10);

    uint256 balanceBeforeStakedToken = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    expectExactEmit();
    emit IStakingVita.Unstaked(user, stakingId, false, false);
    underTest.unstake(stakingId);

    assertEq(balanceBeforeStakedToken - underTest.balanceOf(user), staking);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, staking);
  }

  function test_forceUnstake_thenUnstakesIgnoreLock() external pranking {
    changePrank(user);

    uint128 staking = 23.2e18;
    uint32 stakingId = 1;
    underTest.stake(IStakingVita.ScheduleDuration(0), staking);

    uint256 balanceBeforeStakedToken = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    changePrank(owner);

    expectExactEmit();
    emit IStakingVita.Unstaked(user, stakingId, true, false);
    underTest.forceUnstake(stakingId);

    assertEq(balanceBeforeStakedToken - underTest.balanceOf(user), staking);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, staking);
  }

  function test_forceUnstakeIgnoreBurning_thenUnstakesIgnoringLockAndBurn()
    external
    pranking
  {
    changePrank(user);

    uint128 staking = 23.2e18;
    uint32 stakingId = 1;
    underTest.stake(IStakingVita.ScheduleDuration(0), staking);

    uint256 balanceBeforeStakedToken = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    changePrank(owner);

    expectExactEmit();
    emit IStakingVita.Unstaked(user, stakingId, true, true);
    underTest.forceUnstakeIgnoreBurning(stakingId);

    assertEq(underTest.balanceOf(user), balanceBeforeStakedToken);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, staking);
  }

  function test_executeUnstake_whenNotStakingOwner_thenReverts() external prankAs(user) {
    vm.expectRevert(IStakingVita.NotStakingOwner.selector);
    underTest.exposed_executeUnstake(1, false, false);
  }

  function test_executeUnstake_whenLockNotDone_thenReverts() external prankAs(user) {
    underTest.stake(IStakingVita.ScheduleDuration(0), 1e18);

    vm.expectRevert(IStakingVita.ScheduleNotFinished.selector);
    underTest.exposed_executeUnstake(1, false, false);
  }

  function test_executeUnstake_whenForced_thenIgnoreLockAndOwnership()
    external
    prankAs(user)
  {
    uint128 staking = 0.9e18;
    underTest.stake(IStakingVita.ScheduleDuration(0), staking);

    uint256 balanceBeforeStakeVersion = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    changePrank(generateAddress());

    expectExactEmit();
    emit IStakingVita.Unstaked(user, 1, true, false);
    underTest.exposed_executeUnstake(1, true, false);

    assertEq(balanceBeforeStakeVersion - underTest.balanceOf(user), staking);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, staking);
  }

  function test_executeUnstake_whenIgnoreBurning_thenUnstakeWithoutBurning()
    external
    prankAs(user)
  {
    uint128 staking = 23e18;

    underTest.stake(IStakingVita.ScheduleDuration(0), staking);

    skip(30 days * 10);

    uint256 balanceBeforeStakeVersion = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    expectExactEmit();
    emit IStakingVita.Unstaked(user, 1, false, true);
    underTest.exposed_executeUnstake(1, false, true);

    assertEq(underTest.balanceOf(user), balanceBeforeStakeVersion);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, staking);
  }

  function test_executeUnstake_whenLockOver_thenUnstakes() external prankAs(user) {
    uint128 staking = 0.9e18;
    uint8 durationMode = 1;

    underTest.stake(IStakingVita.ScheduleDuration(durationMode), staking);

    uint256 balanceBeforeStakeVersion = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    skip(underTest.DURATIONS(durationMode));

    expectExactEmit();
    emit IStakingVita.Unstaked(user, 1, false, false);
    underTest.exposed_executeUnstake(1, false, false);

    assertEq(balanceBeforeStakeVersion - underTest.balanceOf(user), staking);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, staking);
  }
}

contract StakingVitaHarness is StakingVita {
  constructor(address _owner) StakingVita(_owner) { }

  function exposed_executeUnstake(uint32 _scheduleId, bool _isForce, bool _ignoreBurning)
    external
  {
    _executeUnstake(_scheduleId, _isForce, _ignoreBurning);
  }
}
