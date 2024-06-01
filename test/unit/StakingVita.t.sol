// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.25;

import "../base/BaseTest.t.sol";
import { StakingVita, IStakingVita } from "src/staking/StakingVita.sol";

import { MockERC20 } from "test/mock/contract/MockERC20.t.sol";

contract StakingVitaTest is BaseTest {
  address private owner = generateAddress("Owner");
  address private user = generateAddress("User");

  StakingVitaHarness private underTest;
  MockERC20 private tokenIn;

  function setUp() external {
    underTest = new StakingVitaHarness(owner);

    tokenIn = MockERC20(address(underTest.TOKEN_IN()));
    vm.etch(address(tokenIn), type(MockERC20).creationCode);

    tokenIn.mint(user, 100e18);
  }

  function test_constructor_thenContractConfiguredCorrectly() external {
    underTest = new StakingVitaHarness(owner);

    assertEq(underTest.owner(), owner);
    assertEq(abi.encode(underTest.name()), abi.encode("Staked Vita"));
    assertEq(abi.encode(underTest.symbol()), abi.encode("stVITA"));
    assertEq(underTest.decimals(), 18);

    assertEq(address(underTest.TOKEN_IN()), 0x81f8f0bb1cB2A06649E51913A151F0E7Ef6FA321);
  }

  function test_stake_thenCreatesStakingSchedule() external prankAs(user) { }
}

contract StakingVitaHarness is StakingVita {
  constructor(address _owner) StakingVita(_owner) { }

  function exposed_unstake(uint32 _scheduleId, bool _isForce, bool _ignoreBurning)
    external
  {
    _unstake(_scheduleId, _isForce, _ignoreBurning);
  }
}
