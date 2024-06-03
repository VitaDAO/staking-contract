// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../BaseScript.sol";

import { VestingVita } from "src/vesting/VestingVita.sol";
import { StakingVita } from "src/staking/StakingVita.sol";

import { MockERC20 } from "test/mock/contract/MockERC20.t.sol";

contract DeployContractsScript is BaseScript {
  string private constant CONFIG_NAME = "ContractsConfig";
  string private constant VESTING_VITA_NAME = "VestingVita";
  string private constant STAKING_VITA_NAME = "StakingVita";
  string private constant TESTNET_ERC20_NAME = "MockERC20";

  uint256 activeDeployer;
  address deployerWallet;

  address private owner = address(0);
  address private vita = address(0x81f8f0bb1cB2A06649E51913A151F0E7Ef6FA321);

  function run() external {
    activeDeployer = _getDeployerPrivateKey();
    deployerWallet = _getDeployerAddress();

    _loadContracts();

    if (_isTestnet()) {
      owner = deployerWallet;
      (vita,) = _tryDeployContract(
        TESTNET_ERC20_NAME,
        0,
        type(MockERC20).creationCode,
        abi.encode("Mock ERC20", "ME20", 18)
      );
    }

    _tryDeployContract(
      VESTING_VITA_NAME, 0, type(VestingVita).creationCode, abi.encode(owner, vita)
    );

    _tryDeployContract(
      STAKING_VITA_NAME, 0, type(StakingVita).creationCode, abi.encode(owner, vita)
    );
  }
}
