// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IDittoAdapter {

    error CounterLimitReached();

    struct Workflow {
        bytes workflow;
        address target;
        uint256 count;
    }

    struct EntryPointStorage {
        mapping(uint256 => Workflow) workflows;
        uint256 workflowIds;
    }

    function addWorkflow(bytes memory _callData, address _target, uint256 _count) external;

    function executeFromDEP(address vault7579, uint256 workflowId) external returns (bytes[] memory returnData);

}
