// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.25;

import "../base/BaseTest.t.sol";
import { LockingVita, ILockingVita } from "src/LockingVita.sol";

import { MockERC20 } from "test/mock/contract/MockERC20.t.sol";

contract LockingVitaTest is BaseTest {
  address private owner;
  address private user;

  LockingVitaHarness private underTest;
  MockERC20 private tokenIn;

  uint128[] depositAmounts;
  uint32[] scheduleIds;

  function setUp() external {
    delete depositAmounts;
    delete scheduleIds;

    createVariables();

    underTest = new LockingVitaHarness(owner, address(tokenIn));
    tokenIn.mint(user, 100e18);
  }

  function createVariables() internal {
    owner = generateAddress("Owner");
    user = generateAddress("User");
    tokenIn = new MockERC20("Mock Token", "MT", 18);
  }

  function test_constructor_thenContractConfiguredCorrectly() external {
    underTest = new LockingVitaHarness(owner, address(tokenIn));

    assertEq(underTest.owner(), owner);
    assertEq(address(underTest.tokenIn()), address(tokenIn));
    assertEq(abi.encode(underTest.name()), abi.encode("Locked Vita"));
    assertEq(abi.encode(underTest.symbol()), abi.encode("stVITA"));
    assertEq(underTest.decimals(), 18);

    assertEq(address(underTest.tokenIn()), address(tokenIn));

    uint8 totalEnums = uint8(type(ILockingVita.ScheduleDuration).max);

    assertEq(totalEnums, 4);

    assertEq(
      underTest.DURATIONS(uint8(ILockingVita.ScheduleDuration.THREE_MONTHS)), 7_889_400
    );
    assertEq(
      underTest.DURATIONS(uint8(ILockingVita.ScheduleDuration.SIX_MONTHS)), 15_778_800
    );
    assertEq(
      underTest.DURATIONS(uint8(ILockingVita.ScheduleDuration.TWELVE_MONTHS)), 31_557_600
    );
    assertEq(
      underTest.DURATIONS(uint8(ILockingVita.ScheduleDuration.TWENTY_FOUR_MONTHS)),
      63_115_200
    );
    assertEq(
      underTest.DURATIONS(uint8(ILockingVita.ScheduleDuration.THIRTY_SIX_MONTHS)),
      94_672_800
    );
  }

  function test_lock_thenCreatesLockingShedule() external prankAs(user) {
    uint8 totalEnums = uint8(type(ILockingVita.ScheduleDuration).max) + 1;
    depositAmounts = [13e18, 9.2e18, 0.1e18, 23.33e18, 44e18];

    uint128 totalAmount = 0;
    uint128 currentAmount = 0;
    ILockingVita.ScheduleDuration scheduleDuration;
    ILockingVita.LockingShedule memory expectedSchedule;

    for (uint32 i = 0; i < totalEnums; ++i) {
      currentAmount = depositAmounts[i];
      scheduleDuration = ILockingVita.ScheduleDuration(i);
      totalAmount += currentAmount;

      expectedSchedule = ILockingVita.LockingShedule({
        locker: user,
        amount: currentAmount,
        end: uint32(block.timestamp) + underTest.DURATIONS(uint8(scheduleDuration)),
        duration: scheduleDuration,
        withdrawn: false
      });

      expectExactEmit();
      emit ILockingVita.Locked(user, uint32(i + 1), scheduleDuration, currentAmount);

      underTest.lock(scheduleDuration, currentAmount);

      assertEq(
        abi.encode(underTest.getLockingShedule(i + 1)), abi.encode(expectedSchedule)
      );

      skip(1.2 days);
    }

    assertEq(underTest.getTotalLocked(user), totalAmount);
    assertEq(underTest.balanceOf(user), totalAmount);
    assertEq(tokenIn.balanceOf(address(underTest)), totalAmount);
    assertEq(underTest.totalLockSchedules(), totalEnums);
  }

  function test_batchUnlock_thenUnlocks() external prankAs(user) {
    depositAmounts = [13e18, 9.2e18, 0.1e18, 23.33e18, 44e18];

    for (uint256 i = 0; i < depositAmounts.length; ++i) {
      underTest.lock(ILockingVita.ScheduleDuration(0), depositAmounts[i]);
    }

    skip(30 days * 10);

    uint256 balanceBeforeLockedToken = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    scheduleIds = [2, 1, 4];
    uint256 totalUnstaking = 0;

    for (uint256 i = 0; i < scheduleIds.length; ++i) {
      totalUnstaking += depositAmounts[scheduleIds[i] - 1];

      expectExactEmit();
      emit ILockingVita.Unlocked(user, scheduleIds[i], false, false);
    }
    underTest.batchUnlock(scheduleIds);

    assertEq(balanceBeforeLockedToken - underTest.balanceOf(user), totalUnstaking);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, totalUnstaking);
  }

  function test_unlock_thenUnlock() external prankAs(user) {
    uint128 staking = 23.2e18;
    uint32 stakingId = 1;
    underTest.lock(ILockingVita.ScheduleDuration(0), staking);

    skip(30 days * 10);

    uint256 balanceBeforeLockedToken = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    expectExactEmit();
    emit ILockingVita.Unlocked(user, stakingId, false, false);
    underTest.unlock(stakingId);

    assertEq(balanceBeforeLockedToken - underTest.balanceOf(user), staking);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, staking);
  }

  function test_forceUnlock_thenUnlocksIgnoreLock() external pranking {
    changePrank(user);

    uint128 staking = 23.2e18;
    uint32 stakingId = 1;
    underTest.lock(ILockingVita.ScheduleDuration(0), staking);

    uint256 balanceBeforeLockedToken = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    changePrank(owner);

    expectExactEmit();
    emit ILockingVita.Unlocked(user, stakingId, true, false);
    underTest.forceUnlock(stakingId);

    assertEq(balanceBeforeLockedToken - underTest.balanceOf(user), staking);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, staking);
  }

  function test_forceUnlockIgnoreBurning_thenUnlocksIgnoringLockAndBurn()
    external
    pranking
  {
    changePrank(user);

    uint128 staking = 23.2e18;
    uint32 stakingId = 1;
    underTest.lock(ILockingVita.ScheduleDuration(0), staking);

    uint256 balanceBeforeLockedToken = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    changePrank(owner);

    expectExactEmit();
    emit ILockingVita.Unlocked(user, stakingId, true, true);
    underTest.forceUnlockIgnoreBurning(stakingId);

    assertEq(underTest.balanceOf(user), balanceBeforeLockedToken);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, staking);
  }

  function test_executeUnlock_whenNotStakingOwner_thenReverts() external prankAs(user) {
    vm.expectRevert(ILockingVita.NotStakingOwner.selector);
    underTest.exposed_executeUnlock(1, false, false);
  }

  function test_executeUnlock_whenLockNotDone_thenReverts() external prankAs(user) {
    underTest.lock(ILockingVita.ScheduleDuration(0), 1e18);

    vm.expectRevert(ILockingVita.ScheduleNotFinished.selector);
    underTest.exposed_executeUnlock(1, false, false);
  }

  function test_executeUnlock_whenWithdrawn_thenReverts() external prankAs(user) {
    uint128 staking = 0.9e18;
    uint8 durationMode = 1;

    underTest.lock(ILockingVita.ScheduleDuration(durationMode), staking);

    skip(underTest.DURATIONS(durationMode));

    underTest.exposed_executeUnlock(1, false, false);
    vm.expectRevert(ILockingVita.StakingAlreadyWithdrawn.selector);
    underTest.exposed_executeUnlock(1, false, false);
  }

  function test_executeUnlock_whenForced_thenIgnoreLockAndOwnership()
    external
    prankAs(user)
  {
    uint128 staking = 0.9e18;
    underTest.lock(ILockingVita.ScheduleDuration(0), staking);

    uint256 balanceBeforeLockVersion = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    changePrank(generateAddress());

    expectExactEmit();
    emit ILockingVita.Unlocked(user, 1, true, false);
    underTest.exposed_executeUnlock(1, true, false);

    assertEq(balanceBeforeLockVersion - underTest.balanceOf(user), staking);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, staking);
  }

  function test_executeUnlock_whenIgnoreBurning_thenUnlockWithoutBurning()
    external
    prankAs(user)
  {
    uint128 staking = 23e18;

    underTest.lock(ILockingVita.ScheduleDuration(0), staking);

    skip(30 days * 10);

    uint256 balanceBeforeLockVersion = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    expectExactEmit();
    emit ILockingVita.Unlocked(user, 1, false, true);
    underTest.exposed_executeUnlock(1, false, true);

    assertEq(underTest.balanceOf(user), balanceBeforeLockVersion);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, staking);
  }

  function test_executeUnlock_whenLockOver_thenUnlocks() external prankAs(user) {
    uint128 staking = 0.9e18;
    uint8 durationMode = 1;

    underTest.lock(ILockingVita.ScheduleDuration(durationMode), staking);

    uint256 balanceBeforeLockVersion = underTest.balanceOf(user);
    uint256 balanceBeforeTokenIn = tokenIn.balanceOf(user);

    skip(underTest.DURATIONS(durationMode));

    expectExactEmit();
    emit ILockingVita.Unlocked(user, 1, false, false);
    underTest.exposed_executeUnlock(1, false, false);

    assertEq(balanceBeforeLockVersion - underTest.balanceOf(user), staking);
    assertEq(tokenIn.balanceOf(user) - balanceBeforeTokenIn, staking);
  }

  function test_transfer_thenReverts() external prankAs(user) {
    underTest.exposed_mint(user, 1e18);

    vm.expectRevert(ILockingVita.TransferNotAllowed.selector);
    underTest.transfer(generateAddress(), 1e18);
  }

  function test_transferFrom_thenReverts() external prankAs(user) {
    address allowanceAddress = generateAddress();

    underTest.exposed_mint(user, 1e18);
    underTest.approve(allowanceAddress, 1e18);

    changePrank(allowanceAddress);
    vm.expectRevert(ILockingVita.TransferNotAllowed.selector);
    underTest.transferFrom(user, generateAddress(), 1e18);
  }
}

contract LockingVitaHarness is LockingVita {
  constructor(address _owner, address _tokenIn) LockingVita(_owner, _tokenIn) { }

  function exposed_executeUnlock(uint32 _scheduleId, bool _isForce, bool _ignoreBurning)
    external
  {
    _executeUnlock(_scheduleId, _isForce, _ignoreBurning);
  }

  function exposed_mint(address _to, uint256 _amount) external {
    _mint(_to, _amount);
  }
}
