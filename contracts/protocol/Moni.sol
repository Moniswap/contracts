// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IMoni} from "./interfaces/IMoni.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title Moni
/// @author moniswap
/// @notice The native token in the Protocol ecosystem
/// @dev Emitted by the Minter
contract Moni is IMoni, ERC20Permit {
    address public minter;
    address private owner;

    constructor() ERC20("Moniswap", "MONI") ERC20Permit("Moniswap") {
        minter = msg.sender;
        owner = msg.sender;
    }

    /// @dev No checks as its meant to be once off to set minting rights to BaseV1 Minter
    function setMinter(address _minter) external {
        if (msg.sender != minter) revert NotMinter();
        minter = _minter;
    }

    function mint(address account, uint256 amount) external returns (bool) {
        if (msg.sender != minter) revert NotMinter();
        _mint(account, amount);
        return true;
    }
}
