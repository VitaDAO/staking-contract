// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.25;

import "../base/BaseTest.t.sol";
import { VestingVita, IVestingVita } from "src/vesting/VestingVita.sol";
import { MockERC20 } from "test/mock/contract/MockERC20.t.sol";

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

contract VestingVitaTest is BaseTest {
  bytes private constant REVERT_UNAUTHORIZED = "UNAUTHORIZED";
  uint256 private constant RAY = 10 ** 27;

  address private owner;
  address private user;

  VestingVitaHarness private underTest;
  MockERC20 private tokenOut;

  function setUp() external {
    createVariables();

    underTest = new VestingVitaHarness(owner);

    tokenOut = MockERC20(address(underTest.TOKEN_OUT()));
    vm.etch(address(tokenOut), address(new MockERC20("Mock Token", "MT", 18)).code);

    tokenOut.mint(owner, 1_000_000e18);
  }

  function createVariables() internal {
    owner = generateAddress("Owner");
    user = generateAddress("User");
  }

  function test_createVesting_asUser_thenReverts() external {
    vm.expectRevert(REVERT_UNAUTHORIZED);
    underTest.createVesting(user, 10 days, 30 days, 100e18, false);
  }

  function test_createVesting_thenCreatesVestingAtCurrentTimestamp()
    external
    prankAs(owner)
  {
    uint128 amount = 3201.1e18;
    uint32 cliff = 10 days;
    uint32 vesting = 30 days;
    uint256 rate = FixedPointMathLib.mulDivDown(amount, RAY, vesting);

    IVestingVita.Vesting memory expected = IVestingVita.Vesting({
      ratePerSecond: rate,
      totalAmount: amount,
      claimed: 0,
      receiver: user,
      start: uint32(block.timestamp),
      cliff: uint32(block.timestamp + cliff),
      end: uint32(block.timestamp + vesting),
      canBeCanceled: true
    });

    emit IVestingVita.VestingCreated(1, user, expected);
    underTest.createVesting(user, cliff, vesting, amount, true);

    assertEq(abi.encode(underTest.getVestingSchedule(1)), abi.encode(expected));

    skip(1 days);

    cliff = 91 days;
    vesting = 111 days;
    rate = FixedPointMathLib.mulDivDown(amount, RAY, vesting);

    expected = IVestingVita.Vesting({
      ratePerSecond: rate,
      totalAmount: amount,
      claimed: 0,
      receiver: user,
      start: uint32(block.timestamp),
      cliff: uint32(block.timestamp + cliff),
      end: uint32(block.timestamp + vesting),
      canBeCanceled: false
    });

    emit IVestingVita.VestingCreated(2, user, expected);
    underTest.createVesting(user, cliff, vesting, amount, false);

    assertEq(abi.encode(underTest.getVestingSchedule(2)), abi.encode(expected));
    assertEq(tokenOut.balanceOf(address(underTest)), amount * 2);
  }

  function test_createVestingWithStartPoint_asUser_thenReverts() external {
    vm.expectRevert(REVERT_UNAUTHORIZED);
    underTest.createVestingWithStartPoint(user, 0, 10 days, 30 days, 100e18, false);
  }

  function test_createVestingWithStartPoint_thenCreatesVestingAtCurrentTimestamp()
    external
    prankAs(owner)
  {
    uint128 amount = 1001.1e18;
    uint32 cliff = 379 days;
    uint32 vesting = 3399 days;
    uint256 rate = FixedPointMathLib.mulDivDown(amount, RAY, vesting);

    uint32 startPoint = uint32(block.timestamp - 377 days);

    IVestingVita.Vesting memory expected = IVestingVita.Vesting({
      ratePerSecond: rate,
      totalAmount: amount,
      claimed: 0,
      receiver: user,
      start: startPoint,
      cliff: startPoint + cliff,
      end: startPoint + vesting,
      canBeCanceled: true
    });

    emit IVestingVita.VestingCreated(1, user, expected);
    underTest.createVestingWithStartPoint(user, startPoint, cliff, vesting, amount, true);

    assertEq(abi.encode(underTest.getVestingSchedule(1)), abi.encode(expected));

    skip(10 days);

    startPoint = uint32(block.timestamp + 399 days);

    cliff = 91 days;
    vesting = 111 days;
    rate = FixedPointMathLib.mulDivDown(amount, RAY, vesting);

    expected = IVestingVita.Vesting({
      ratePerSecond: rate,
      totalAmount: amount,
      claimed: 0,
      receiver: user,
      start: startPoint,
      cliff: startPoint + cliff,
      end: startPoint + vesting,
      canBeCanceled: false
    });

    emit IVestingVita.VestingCreated(2, user, expected);
    underTest.createVestingWithStartPoint(user, startPoint, cliff, vesting, amount, false);

    assertEq(abi.encode(underTest.getVestingSchedule(2)), abi.encode(expected));
    assertEq(tokenOut.balanceOf(address(underTest)), amount * 2);
  }

  function test_create_givenEmptyAddress_thenReverts() external prankAs(owner) {
    vm.expectRevert(IVestingVita.AddressCannotBeZero.selector);
    underTest.exposed_create(address(0), 30 days, 32 days, 31 days, 1e18, false);
  }

  function test_create_whenCliffIsHigherThanEnd_thenReverts() external prankAs(owner) {
    vm.expectRevert(
      abi.encodeWithSelector(
        IVestingVita.CreateVestingError.selector, "Cliff Timestamp > End Timestamp"
      )
    );
    underTest.exposed_create(user, 30 days, 32 days, 31 days, 1e18, false);
  }

  function test_create_whenEndIsExpiredOrZero_thenReverts() external prankAs(owner) {
    uint32 startTime = uint32(block.timestamp);

    vm.expectRevert(
      abi.encodeWithSelector(
        IVestingVita.CreateVestingError.selector, "End Timestamp is already expired"
      )
    );
    underTest.exposed_create(user, startTime, 0 days, 0 days, 1e18, false);
    vm.expectRevert(
      abi.encodeWithSelector(
        IVestingVita.CreateVestingError.selector, "End Timestamp is already expired"
      )
    );
    underTest.exposed_create(user, startTime - 1 days, 0 days, 0.6 days, 1e18, false);
  }

  function test_create_whenCliffIsAlreadyExpired_thenReverts() external prankAs(owner) {
    vm.expectRevert(
      abi.encodeWithSelector(
        IVestingVita.CreateVestingError.selector, "Cliff Timestamp is already expired"
      )
    );
    underTest.exposed_create(
      user, uint32(block.timestamp - 30 days), 29.9 days, 30.1 days, 1e18, false
    );
  }

  function test_create_thenCreatesVesting() external prankAs(owner) {
    uint32 cliffDuration = 10 days;
    uint32 endDuration = 128 days;
    uint128 amountIn = 19.2e18;
    uint256 rate = FixedPointMathLib.mulDivDown(amountIn, RAY, endDuration);

    for (uint32 i = 0; i < 5; ++i) {
      uint32 start = uint32(block.timestamp);

      IVestingVita.Vesting memory expected = IVestingVita.Vesting({
        ratePerSecond: rate,
        totalAmount: amountIn,
        claimed: 0,
        receiver: user,
        start: start,
        cliff: start + cliffDuration,
        end: start + endDuration,
        canBeCanceled: i == 3
      });

      expectExactEmit();
      emit IVestingVita.VestingCreated(i + 1, user, expected);

      underTest.exposed_create(user, start, cliffDuration, endDuration, amountIn, i == 3);
      assertEq(abi.encode(underTest.getVestingSchedule(i + 1)), abi.encode(expected));
    }

    assertEq(tokenOut.balanceOf(address(underTest)), amountIn * 5);
    assertEq(underTest.tokenOutBalanceOf(user), amountIn * 5);
  }

  function test_claim_whenNotReceiver_thenReverts() external prankAs(owner) {
    uint128 amount = 3201.1e18;
    uint32 cliff = 10 days;
    uint32 vesting = 30 days;

    underTest.createVesting(user, cliff, vesting, amount, true);

    vm.expectRevert(IVestingVita.NotVestingReceiver.selector);
    underTest.claim(1);

    changePrank(generateAddress());

    vm.expectRevert(IVestingVita.NotVestingReceiver.selector);
    underTest.claim(1);
  }

  function test_claim_whenNothing_thenReverts() external pranking {
    uint128 amount = 3201.1e18;
    uint32 cliff = 10 days;
    uint32 vesting = 30 days;

    changePrank(owner);
    underTest.createVesting(user, cliff, vesting, amount, true);

    changePrank(user);

    vm.expectRevert(IVestingVita.NothingToClaim.selector);
    underTest.claim(1);
  }

  function test_claim_whenPendingReward_thenClaims() external pranking {
    uint128 amount = 3201.1e18;
    uint32 cliff = 10 days;
    uint32 vesting = 30 days;

    changePrank(owner);

    underTest.createVesting(user, cliff, vesting, amount, true);

    changePrank(user);
    skip(12 days);

    (uint256 expectingReward, uint256 remaining) = underTest.getUnlockedToken(1);
    underTest.claim(1);

    (uint256 nextReward,) = underTest.getUnlockedToken(1);

    assertEq(tokenOut.balanceOf(user), expectingReward);
    assertEq(underTest.tokenOutBalanceOf(user), amount - expectingReward);
    assertEq(underTest.tokenOutBalanceOf(user), remaining);
    assertEq(nextReward, 0);
  }

  function test_cancelVesting_whenNotOwner_thenReverts() external {
    vm.expectRevert(REVERT_UNAUTHORIZED);
    underTest.cancelVesting(1, false);
  }

  function test_cancelVesting_whenVestingNotFound_thenReverts() external prankAs(owner) {
    vm.expectRevert(IVestingVita.VestingNotFound.selector);
    underTest.cancelVesting(1, false);
  }

  function test_cancelVesting_whenVestingCannotBeCanceled_thenReverts()
    external
    prankAs(owner)
  {
    uint128 amount = 3201.1e18;
    uint32 cliff = 10 days;
    uint32 vesting = 30 days;

    underTest.createVesting(user, cliff, vesting, amount, false);

    vm.expectRevert(IVestingVita.VestingCannotBeCanceled.selector);
    underTest.cancelVesting(1, false);
  }

  function test_cancelVesting_givenNotSendingVestedReward_thenCancelAndDoNotSendUnlockedReward(
  ) external prankAs(owner) {
    uint128 amount = 3201.1e18;
    uint32 cliff = 10 days;
    uint32 vesting = 30 days;

    underTest.createVesting(user, cliff, vesting, amount, true);

    uint256 balanceBefore = tokenOut.balanceOf(owner);

    skip(15 days);

    expectExactEmit();
    emit IVestingVita.VestingCanceled(1, false);
    underTest.cancelVesting(1, false);

    assertEq(tokenOut.balanceOf(user), 0);
    assertEq(underTest.tokenOutBalanceOf(user), 0);
    assertEq(tokenOut.balanceOf(owner) - balanceBefore, amount);
  }

  function test_cancelVesting_givenSendingVestedReward_thenCancelAndSendsUnlocked()
    external
    prankAs(owner)
  {
    uint128 amountA = 1201.1e18;
    uint128 amountB = 3201.1e18;
    uint32 cliff = 10 days;
    uint32 vesting = 30 days;

    underTest.createVesting(user, cliff, vesting, amountA, true);
    underTest.createVesting(user, cliff, vesting, amountB, true);

    uint256 balanceBefore = tokenOut.balanceOf(owner);

    skip(15 days);
    (uint256 expectedReward,) = underTest.getUnlockedToken(2);

    expectExactEmit();
    emit IVestingVita.VestingCanceled(2, true);
    underTest.cancelVesting(2, true);

    assertEq(tokenOut.balanceOf(user), expectedReward);
    assertEq(underTest.tokenOutBalanceOf(user), amountA);
    assertEq(tokenOut.balanceOf(owner) - balanceBefore, amountB - expectedReward);
  }

  function test_fizz_getUnlockedToken_thenFormulaWorks() external prankAs(owner) {
    uint128 amount = 540_201.33e18;
    uint32 cliff = 200 days;
    uint32 vesting = 365 days;

    uint256 cliffAmount = 296_000_728_767_123_287_671_232;

    uint256 returnedReward = 0;

    underTest.createVesting(user, cliff, vesting, amount, true);

    skip(cliff - 1);
    (returnedReward,) = underTest.getUnlockedToken(1);

    assertEq(returnedReward, 0);

    skip(1);
    (returnedReward,) = underTest.getUnlockedToken(1);

    assertEq(returnedReward, cliffAmount);

    skip(1 days);

    (uint256 returnedRewardOneMoreDay,) = underTest.getUnlockedToken(1);
    assertEq(returnedRewardOneMoreDay - returnedReward, 1_480_003_643_835_616_438_357);

    skip(vesting - cliff - 1 days);
    (returnedReward,) = underTest.getUnlockedToken(1);

    assertEq(returnedReward, amount);

    skip(360 days);
    (returnedReward,) = underTest.getUnlockedToken(1);

    assertEq(returnedReward, amount);
  }

  function test_fizz_getUnlockedToken_thenFormulaWorks(
    uint128[10] calldata _rewards,
    uint16[10] calldata _cliffs,
    uint16[10] calldata _vestings,
    uint16[10] calldata _skips
  ) external pranking {
    uint128 reward = 0;
    uint16 cliff = 0;
    uint16 vesting = 0;
    uint16 skipping = 0;

    for (uint32 i = 1; i < _rewards.length; ++i) {
      address vestingOwner = i % 2 == 0 ? user : generateAddress();

      tokenOut.burn(owner, tokenOut.balanceOf(owner));
      tokenOut.mint(owner, type(uint128).max);

      reward = uint128(bound(_rewards[i], 1e6, type(uint128).max));
      vesting = uint16(bound(_vestings[i], 1, type(uint16).max));
      cliff = uint16(bound(_cliffs[i], 0, vesting - 1));
      skipping = uint16(bound(_skips[i], 1, vesting));

      uint256 rate = FixedPointMathLib.mulDivDown(reward, RAY, vesting);

      changePrank(owner);

      underTest.createVesting(vestingOwner, cliff, vesting, reward, true);

      skip(skipping);

      uint256 expectReward =
        skipping < cliff ? 0 : FixedPointMathLib.mulDivDown(skipping, rate, RAY);

      if (skipping >= vesting) expectReward = reward;

      (uint256 returnedReward,) = underTest.getUnlockedToken(i);

      assertEq(returnedReward, expectReward);

      if (returnedReward == 0) continue;
      changePrank(vestingOwner);
      underTest.claim(i);
    }
  }
}

contract VestingVitaHarness is VestingVita {
  constructor(address _owner) VestingVita(_owner) { }

  function exposed_create(
    address _receiver,
    uint32 _startTimestamp,
    uint32 _cliffDuration,
    uint32 _endDuration,
    uint128 _amount,
    bool _canBeCanceled
  ) external {
    _create(
      _receiver, _startTimestamp, _cliffDuration, _endDuration, _amount, _canBeCanceled
    );
  }
}
