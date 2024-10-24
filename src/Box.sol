// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    constructor() Ownable(msg.sender) {}

    uint256 private s_number;

    event NumberChanged(uint256 number);

    function updateNum(uint256 _num) public onlyOwner {
        s_number = _num;
        emit NumberChanged(_num);
    }

    function getNumber() public view returns (uint256) {
        return s_number;
    }
}
