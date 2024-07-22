// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IMockTarget {
    function setValue(uint256 _value) external returns (uint256);

    function incrementValue() external;

    function incrementValueTwice() external;

    function getValue() external returns(uint256);
}